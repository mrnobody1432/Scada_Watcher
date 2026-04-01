using Microsoft.Extensions.Options;
using Opc.Ua;
using Opc.Ua.Client;
using Opc.Ua.Configuration;

namespace ScadaWatcherService;

/// <summary>
/// Production-grade OPC UA client service for industrial SCADA data acquisition.
/// Implements subscription-based data change monitoring with automatic reconnection.
/// Designed for 24/7 operation with comprehensive error handling and logging.
/// 
/// Key Features:
/// - Read-only client (no writes to prevent safety issues)
/// - Subscription-based monitoring (efficient, event-driven)
/// - Automatic reconnection with exponential backoff
/// - Certificate validation and security policy support
/// - Never crashes or blocks the main service thread
/// - Comprehensive Serilog logging of all events
/// </summary>
public class OpcUaClientService : IDisposable
{
    private readonly ILogger<OpcUaClientService> _logger;
    private readonly OpcUaConfiguration _config;
    
    private ApplicationInstance? _application;
    private Session? _session;
    private Subscription? _subscription;
    private ConfiguredEndpoint? _endpoint;
    
    private bool _isRunning = false;
    private bool _disposed = false;
    private int _currentReconnectDelay;
    private DateTime _lastConnectionAttempt = DateTime.MinValue;
    private int _reconnectAttemptCount = 0;
    
    private readonly object _sessionLock = new object();
    private CancellationTokenSource? _reconnectCts;

    /// <summary>
    /// Event raised when new OPC UA data is received.
    /// Subscribers can process data without blocking the OPC UA client.
    /// </summary>
    public event EventHandler<OpcUaDataValue>? DataReceived;

    /// <summary>
    /// Event raised when connection state changes.
    /// Useful for monitoring and alerting systems.
    /// </summary>
    public event EventHandler<bool>? ConnectionStateChanged;

    public OpcUaClientService(
        ILogger<OpcUaClientService> logger,
        IOptions<OpcUaConfiguration> config)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _config = config?.Value ?? throw new ArgumentNullException(nameof(config));
        _currentReconnectDelay = _config.ReconnectDelaySeconds;
    }

    /// <summary>
    /// Start the OPC UA client and establish initial connection.
    /// Safe to call multiple times - will only start once.
    /// </summary>
    public async Task StartAsync(CancellationToken cancellationToken = default)
    {
        if (_isRunning)
        {
            _logger.LogWarning("OPC UA client is already running. Ignoring start request.");
            return;
        }

        if (!_config.Enabled)
        {
            _logger.LogInformation("OPC UA client is disabled in configuration. Not starting.");
            return;
        }

        _logger.LogInformation("=== OPC UA Client Starting ===");
        _logger.LogInformation("Endpoint: {Endpoint}", _config.EndpointUrl);
        _logger.LogInformation("Security Mode: {Mode}", _config.SecurityMode);
        _logger.LogInformation("Security Policy: {Policy}", _config.SecurityPolicy);
        _logger.LogInformation("Authentication: {Auth}", _config.AuthenticationMode);
        _logger.LogInformation("Monitoring {Count} nodes", _config.Nodes.Count);

        // Validate configuration before attempting connection
        if (!ValidateConfiguration())
        {
            _logger.LogError("OPC UA configuration validation failed. Client will not start.");
            return;
        }

        _isRunning = true;
        _reconnectCts = new CancellationTokenSource();

        try
        {
            // Initialize OPC UA application instance
            await InitializeApplicationAsync();

            // Attempt initial connection
            await ConnectAsync(cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to start OPC UA client. Will retry with exponential backoff.");
            
            // Don't fail - schedule reconnection attempt
            _ = Task.Run(() => ReconnectLoopAsync(_reconnectCts.Token), _reconnectCts.Token);
        }
    }

    /// <summary>
    /// Stop the OPC UA client and clean up all resources gracefully.
    /// </summary>
    public async Task StopAsync(CancellationToken cancellationToken = default)
    {
        if (!_isRunning)
        {
            return;
        }

        _logger.LogInformation("OPC UA client stopping...");
        _isRunning = false;

        // Cancel any reconnection attempts
        _reconnectCts?.Cancel();

        // Disconnect from server
        await DisconnectAsync();

        _logger.LogInformation("OPC UA client stopped.");
    }

    /// <summary>
    /// Validate configuration before attempting connection.
    /// Prevents startup with invalid settings.
    /// </summary>
    private bool ValidateConfiguration()
    {
        if (string.IsNullOrWhiteSpace(_config.EndpointUrl))
        {
            _logger.LogError("VALIDATION ERROR: EndpointUrl is not configured.");
            return false;
        }

        if (!_config.EndpointUrl.StartsWith("opc.tcp://", StringComparison.OrdinalIgnoreCase))
        {
            _logger.LogError("VALIDATION ERROR: EndpointUrl must start with 'opc.tcp://'");
            return false;
        }

        if (_config.Nodes == null || _config.Nodes.Count == 0)
        {
            _logger.LogWarning("VALIDATION WARNING: No nodes configured for monitoring.");
        }

        if (_config.AuthenticationMode == "UsernamePassword" && 
            (string.IsNullOrWhiteSpace(_config.Username) || string.IsNullOrWhiteSpace(_config.Password)))
        {
            _logger.LogError("VALIDATION ERROR: Username/Password authentication requires both username and password.");
            return false;
        }

        _logger.LogInformation("OPC UA configuration validation passed.");
        return true;
    }

    /// <summary>
    /// Initialize OPC UA application instance with security configuration.
    /// Creates application certificate if needed.
    /// </summary>
    private async Task InitializeApplicationAsync()
    {
        try
        {
            _logger.LogInformation("Initializing OPC UA application instance...");

            var application = new ApplicationInstance
            {
                ApplicationName = _config.ApplicationName,
                ApplicationType = ApplicationType.Client,
                ConfigSectionName = "ScadaWatcherOpcUaClient"
            };

            // Create application configuration
            var config = new ApplicationConfiguration
            {
                ApplicationName = _config.ApplicationName,
                ApplicationUri = _config.ApplicationUri,
                ApplicationType = ApplicationType.Client,
                
                SecurityConfiguration = new SecurityConfiguration
                {
                    ApplicationCertificate = new CertificateIdentifier(),
                    TrustedPeerCertificates = new CertificateTrustList(),
                    TrustedIssuerCertificates = new CertificateTrustList(),
                    RejectedCertificateStore = new CertificateTrustList(),
                    AutoAcceptUntrustedCertificates = _config.AutoAcceptCertificates,
                    RejectSHA1SignedCertificates = false,
                    MinimumCertificateKeySize = 2048
                },

                TransportConfigurations = new TransportConfigurationCollection(),
                TransportQuotas = new TransportQuotas { OperationTimeout = 15000 },
                ClientConfiguration = new ClientConfiguration { DefaultSessionTimeout = _config.SessionTimeoutMs },
                TraceConfiguration = new TraceConfiguration()
            };

            // Validate and update application configuration
            await application.CheckApplicationInstanceCertificate(false, 0);
            application.ApplicationConfiguration = config;

            // Handle certificate validation
            application.ApplicationConfiguration.CertificateValidator.CertificateValidation += 
                CertificateValidator_CertificateValidation;

            _application = application;
            
            _logger.LogInformation("OPC UA application initialized successfully.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to initialize OPC UA application instance.");
            throw;
        }
    }

    /// <summary>
    /// Certificate validation callback.
    /// Handles untrusted certificates based on configuration.
    /// Production: Must validate properly. Testing: Can auto-accept.
    /// </summary>
    private void CertificateValidator_CertificateValidation(
        CertificateValidator validator,
        CertificateValidationEventArgs e)
    {
        try
        {
            if (e.Error.StatusCode == StatusCodes.BadCertificateUntrusted)
            {
                if (_config.AcceptUntrustedCertificates)
                {
                    _logger.LogWarning(
                        "Accepting untrusted certificate from {Subject} (configured to accept untrusted)",
                        e.Certificate.Subject);
                    e.Accept = true;
                }
                else
                {
                    _logger.LogError(
                        "Rejecting untrusted certificate from {Subject}. " +
                        "Set AcceptUntrustedCertificates=true to override (not recommended for production).",
                        e.Certificate.Subject);
                    e.Accept = false;
                }
            }
            else if (e.Error.StatusCode != StatusCodes.Good)
            {
                _logger.LogWarning(
                    "Certificate validation issue: {StatusCode} for {Subject}",
                    e.Error.StatusCode,
                    e.Certificate.Subject);
                
                // Auto-accept if configured
                e.Accept = _config.AutoAcceptCertificates;
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error in certificate validation callback.");
            e.Accept = false;
        }
    }

    /// <summary>
    /// Connect to OPC UA server and create subscription.
    /// Handles endpoint discovery, session creation, and monitored item setup.
    /// </summary>
    private async Task ConnectAsync(CancellationToken cancellationToken)
    {
        lock (_sessionLock)
        {
            if (_session != null && !_session.Disposed)
            {
                _logger.LogInformation("Session already exists. Disconnecting before reconnecting.");
                try
                {
                    _session.Close();
                    _session.Dispose();
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Error closing existing session.");
                }
                _session = null;
            }
        }

        try
        {
            _logger.LogInformation("Discovering OPC UA endpoints at {Url}...", _config.EndpointUrl);

            // Discover endpoints
            var endpointUrl = new Uri(_config.EndpointUrl);
            var endpoints = await DiscoverEndpointsAsync(endpointUrl);

            if (endpoints == null || endpoints.Count == 0)
            {
                throw new InvalidOperationException($"No endpoints discovered at {_config.EndpointUrl}");
            }

            _logger.LogInformation("Discovered {Count} endpoint(s).", endpoints.Count);

            // Select endpoint based on security policy
            var selectedEndpoint = SelectEndpoint(endpoints);
            if (selectedEndpoint == null)
            {
                throw new InvalidOperationException(
                    $"No suitable endpoint found with security policy '{_config.SecurityPolicy}' " +
                    $"and mode '{_config.SecurityMode}'");
            }

            _logger.LogInformation(
                "Selected endpoint: {Url}, Security: {Mode}/{Policy}",
                selectedEndpoint.EndpointUrl,
                selectedEndpoint.SecurityMode,
                selectedEndpoint.SecurityPolicyUri);

            // Create configured endpoint
            var endpointConfiguration = EndpointConfiguration.Create(_application!.ApplicationConfiguration);
            _endpoint = new ConfiguredEndpoint(null, selectedEndpoint, endpointConfiguration);

            // Create user identity
            UserIdentity userIdentity = _config.AuthenticationMode == "UsernamePassword"
                ? new UserIdentity(_config.Username, _config.Password)
                : new UserIdentity(new AnonymousIdentityToken());

            _logger.LogInformation("Creating OPC UA session...");

            // Create session
            var session = await Session.Create(
                _application!.ApplicationConfiguration,
                _endpoint,
                false,
                _config.ApplicationName,
                (uint)_config.SessionTimeoutMs,
                userIdentity,
                null);

            if (session == null || session.Disposed)
            {
                throw new InvalidOperationException("Failed to create OPC UA session.");
            }

            // Configure session keep-alive
            session.KeepAliveInterval = _config.KeepAliveIntervalMs;
            session.KeepAlive += Session_KeepAlive;

            lock (_sessionLock)
            {
                _session = session;
            }

            _logger.LogInformation(
                "OPC UA session created successfully. SessionId: {SessionId}",
                session.SessionId);

            // Create subscription for data change notifications
            await CreateSubscriptionAsync();

            // Reset reconnection backoff on successful connection
            _currentReconnectDelay = _config.ReconnectDelaySeconds;
            _reconnectAttemptCount = 0;
            _lastConnectionAttempt = DateTime.UtcNow;

            // Notify connection state change
            ConnectionStateChanged?.Invoke(this, true);

            _logger.LogInformation("OPC UA client connected successfully.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to connect to OPC UA server.");
            
            // Notify connection state change
            ConnectionStateChanged?.Invoke(this, false);
            
            throw;
        }
    }

    /// <summary>
    /// Discover available OPC UA endpoints at the server.
    /// </summary>
    private async Task<EndpointDescriptionCollection?> DiscoverEndpointsAsync(Uri endpointUrl)
    {
        try
        {
            using (var discoveryClient = DiscoveryClient.Create(endpointUrl))
            {
                var response = await discoveryClient.GetEndpointsAsync(
                    null,
                    endpointUrl.ToString(),
                    null,
                    null,
                    CancellationToken.None);

                return response?.Endpoints != null ? new EndpointDescriptionCollection(response.Endpoints) : null;
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Endpoint discovery failed for {Url}", endpointUrl);
            throw;
        }
    }

    /// <summary>
    /// Select the most appropriate endpoint based on security configuration.
    /// Prioritizes endpoints matching configured security policy and mode.
    /// </summary>
    private EndpointDescription? SelectEndpoint(EndpointDescriptionCollection endpoints)
    {
        // Parse configured security mode
        MessageSecurityMode targetSecurityMode = _config.SecurityMode.ToLowerInvariant() switch
        {
            "sign" => MessageSecurityMode.Sign,
            "signandencrypt" => MessageSecurityMode.SignAndEncrypt,
            _ => MessageSecurityMode.None
        };

        // Build target security policy URI
        string targetPolicyUri = _config.SecurityPolicy.ToLowerInvariant() switch
        {
            "basic256sha256" => SecurityPolicies.Basic256Sha256,
            "aes128_sha256_rsaoaep" => SecurityPolicies.Aes128_Sha256_RsaOaep,
            "aes256_sha256_rsapss" => SecurityPolicies.Aes256_Sha256_RsaPss,
            _ => SecurityPolicies.None
        };

        // Find exact match first
        var exactMatch = endpoints.FirstOrDefault(e =>
            e.SecurityMode == targetSecurityMode &&
            e.SecurityPolicyUri == targetPolicyUri);

        if (exactMatch != null)
        {
            return exactMatch;
        }

        // If no exact match and security is None, accept any None endpoint
        if (targetSecurityMode == MessageSecurityMode.None)
        {
            var noneEndpoint = endpoints.FirstOrDefault(e => e.SecurityMode == MessageSecurityMode.None);
            if (noneEndpoint != null)
            {
                _logger.LogWarning(
                    "Using endpoint with security policy {Policy} instead of {Requested}",
                    noneEndpoint.SecurityPolicyUri,
                    targetPolicyUri);
                return noneEndpoint;
            }
        }

        // Log available endpoints for troubleshooting
        _logger.LogWarning("Available endpoints:");
        foreach (var ep in endpoints)
        {
            _logger.LogWarning(
                "  - {Url}, Mode: {Mode}, Policy: {Policy}",
                ep.EndpointUrl,
                ep.SecurityMode,
                ep.SecurityPolicyUri);
        }

        return null;
    }

    /// <summary>
    /// Create subscription and add monitored items for configured nodes.
    /// Uses data change notifications for efficient event-driven updates.
    /// </summary>
    private async Task CreateSubscriptionAsync()
    {
        if (_session == null || _session.Disposed)
        {
            throw new InvalidOperationException("Cannot create subscription without active session.");
        }

        try
        {
            _logger.LogInformation("Creating OPC UA subscription...");

            // Create subscription
            var subscription = new Subscription(_session.DefaultSubscription)
            {
                PublishingEnabled = true,
                PublishingInterval = _config.PublishingIntervalMs,
                KeepAliveCount = 10,
                LifetimeCount = 1000,
                MaxNotificationsPerPublish = 1000,
                Priority = 100
            };

            // Add monitored items for each configured node
            foreach (var nodeConfig in _config.Nodes)
            {
                try
                {
                    if (string.IsNullOrWhiteSpace(nodeConfig.NodeId))
                    {
                        _logger.LogWarning("Skipping node with empty NodeId.");
                        continue;
                    }

                    var nodeId = new NodeId(nodeConfig.NodeId);
                    var samplingInterval = nodeConfig.SamplingIntervalMs ?? _config.SamplingIntervalMs;

                    var monitoredItem = new MonitoredItem
                    {
                        DisplayName = nodeConfig.DisplayName ?? nodeConfig.NodeId,
                        StartNodeId = nodeId,
                        AttributeId = Attributes.Value,
                        SamplingInterval = samplingInterval,
                        QueueSize = (uint)_config.QueueSize,
                        DiscardOldest = true
                    };

                    // Configure deadband filter if specified
                    if (nodeConfig.DeadbandType != "None" && nodeConfig.DeadbandValue > 0)
                    {
                        var filterType = nodeConfig.DeadbandType == "Percent"
                            ? (uint)DeadbandType.Percent
                            : (uint)DeadbandType.Absolute;

                        monitoredItem.Filter = new DataChangeFilter
                        {
                            Trigger = DataChangeTrigger.StatusValue,
                            DeadbandType = filterType,
                            DeadbandValue = nodeConfig.DeadbandValue
                        };
                    }

                    // Attach notification handler
                    monitoredItem.Notification += MonitoredItem_Notification;

                    subscription.AddItem(monitoredItem);

                    _logger.LogInformation(
                        "Added monitored item: {DisplayName} ({NodeId}), Sampling: {Interval}ms",
                        monitoredItem.DisplayName,
                        nodeConfig.NodeId,
                        samplingInterval);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Failed to add monitored item for node {NodeId}", nodeConfig.NodeId);
                }
            }

            // Add subscription to session
            _session.AddSubscription(subscription);
            await subscription.CreateAsync();

            _subscription = subscription;

            _logger.LogInformation(
                "Subscription created successfully with {Count} monitored items.",
                subscription.MonitoredItemCount);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to create OPC UA subscription.");
            throw;
        }
    }

    /// <summary>
    /// Handle data change notifications from OPC UA server.
    /// Normalizes data and raises DataReceived event for processing.
    /// Never throws exceptions to prevent subscription disruption.
    /// </summary>
    private void MonitoredItem_Notification(MonitoredItem monitoredItem, MonitoredItemNotificationEventArgs e)
    {
        try
        {
            if (e.NotificationValue is not MonitoredItemNotification notification)
            {
                return;
            }

            var dataValue = notification.Value;
            if (dataValue == null)
            {
                return;
            }

            // Find node configuration for display name
            var nodeConfig = _config.Nodes.FirstOrDefault(n => n.NodeId == monitoredItem.StartNodeId.ToString());
            var displayName = nodeConfig?.DisplayName ?? monitoredItem.DisplayName;

            // Normalize to internal data model
            var normalizedValue = new OpcUaDataValue
            {
                NodeId = monitoredItem.StartNodeId.ToString(),
                DisplayName = displayName,
                SourceTimestamp = dataValue.SourceTimestamp,
                ReceivedTimestamp = DateTime.UtcNow,
                StatusCode = dataValue.StatusCode.Code,
                StatusDescription = StatusCode.LookupSymbolicId(dataValue.StatusCode.Code),
                IsGoodQuality = StatusCode.IsGood(dataValue.StatusCode),
                DataType = dataValue.Value?.GetType().Name ?? "null",
                Value = dataValue.Value
            };

            // Log data received (rate-limited for production)
            _logger.LogDebug(
                "Data received: {DisplayName} = {Value} [{Type}], Quality: {Quality}, Timestamp: {Timestamp}",
                normalizedValue.DisplayName,
                normalizedValue.ValueAsString,
                normalizedValue.DataType,
                normalizedValue.StatusDescription,
                normalizedValue.SourceTimestamp);

            // Raise event for subscribers
            DataReceived?.Invoke(this, normalizedValue);
        }
        catch (Exception ex)
        {
            // CRITICAL: Never throw from notification handler
            _logger.LogError(ex, "Error processing data notification from {NodeId}", monitoredItem.StartNodeId);
        }
    }

    /// <summary>
    /// Keep-alive handler to monitor session health.
    /// </summary>
    private void Session_KeepAlive(ISession session, KeepAliveEventArgs e)
    {
        try
        {
            if (ServiceResult.IsBad(e.Status))
            {
                _logger.LogWarning(
                    "Keep-alive failed with status: {Status}. Session may be disconnected.",
                    e.Status);

                // Trigger reconnection
                if (_isRunning && _reconnectCts != null && !_reconnectCts.Token.IsCancellationRequested)
                {
                    _ = Task.Run(() => ReconnectLoopAsync(_reconnectCts.Token), _reconnectCts.Token);
                }
            }
            else
            {
                _logger.LogDebug("Keep-alive received. Session is healthy.");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error in keep-alive handler.");
        }
    }

    /// <summary>
    /// Reconnection loop with exponential backoff.
    /// Continuously attempts to reconnect until successful or service stops.
    /// </summary>
    private async Task ReconnectLoopAsync(CancellationToken cancellationToken)
    {
        while (_isRunning && !cancellationToken.IsCancellationRequested)
        {
            try
            {
                // Calculate exponential backoff delay
                var timeSinceLastAttempt = DateTime.UtcNow - _lastConnectionAttempt;
                if (timeSinceLastAttempt.TotalSeconds < 60 && _reconnectAttemptCount > 0)
                {
                    _currentReconnectDelay = Math.Min(
                        _currentReconnectDelay * 2,
                        _config.MaxReconnectDelaySeconds);

                    _logger.LogWarning(
                        "Applying exponential backoff: {Delay} seconds before reconnect attempt.",
                        _currentReconnectDelay);
                }
                else
                {
                    // Reset backoff if last attempt was > 60 seconds ago
                    _currentReconnectDelay = _config.ReconnectDelaySeconds;
                    _reconnectAttemptCount = 0;
                }

                // Wait before reconnection attempt
                await Task.Delay(TimeSpan.FromSeconds(_currentReconnectDelay), cancellationToken);

                _logger.LogInformation("Attempting to reconnect to OPC UA server (attempt #{Attempt})...",
                    _reconnectAttemptCount + 1);

                _reconnectAttemptCount++;
                _lastConnectionAttempt = DateTime.UtcNow;

                // Attempt reconnection
                await ConnectAsync(cancellationToken);

                _logger.LogInformation("Reconnection successful.");
                return; // Exit loop on success
            }
            catch (OperationCanceledException)
            {
                _logger.LogInformation("Reconnection cancelled.");
                return;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Reconnection attempt failed. Will retry with backoff.");
            }
        }
    }

    /// <summary>
    /// Disconnect from OPC UA server and clean up resources.
    /// </summary>
    private async Task DisconnectAsync()
    {
        try
        {
            // Remove subscription
            if (_subscription != null)
            {
                try
                {
                    await _subscription.DeleteAsync(true);
                    _subscription.Dispose();
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Error removing subscription during disconnect.");
                }
                _subscription = null;
            }

            // Close session
            lock (_sessionLock)
            {
                if (_session != null && !_session.Disposed)
                {
                    try
                    {
                        _session.Close();
                        _session.Dispose();
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "Error closing session during disconnect.");
                    }
                    _session = null;
                }
            }

            // Notify connection state change
            ConnectionStateChanged?.Invoke(this, false);

            _logger.LogInformation("Disconnected from OPC UA server.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during OPC UA disconnect.");
        }
    }

    /// <summary>
    /// Dispose pattern implementation for resource cleanup.
    /// </summary>
    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _logger.LogInformation("Disposing OPC UA client service...");

        // Cancel reconnection attempts
        _reconnectCts?.Cancel();
        _reconnectCts?.Dispose();

        // Disconnect synchronously
        DisconnectAsync().GetAwaiter().GetResult();

        _disposed = true;
        _logger.LogInformation("OPC UA client service disposed.");
    }
}
