using Google.Cloud.Firestore;
using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using System.Collections.Concurrent;

namespace ScadaWatcherService;

/// <summary>
/// Production-grade notification adapter for Firebase cloud integration.
/// Synchronizes alert state to Firestore and sends push notifications to mobile devices.
/// 
/// ARCHITECTURE:
/// - Subscribes to alert engine events (AlertRaised, AlertCleared, AlertEscalated)
/// - Non-blocking async operations (never blocks alert engine)
/// - Retry logic with exponential backoff
/// - Notification throttling to prevent spam
/// - REAL-TIME Firestore acknowledgement listener (two-way sync)
/// 
/// SAFETY:
/// - All Firebase operations wrapped in try-catch
/// - Service continues running even if Firebase is offline
/// - Never crashes the Windows Service
/// </summary>
public class NotificationAdapterService
{
    private readonly ILogger<NotificationAdapterService> _logger;
    private readonly FirebaseConfiguration _config;
    private readonly AlertEngineService _alertEngine;
    
    private FirestoreDb? _firestoreDb;
    private FirebaseApp? _firebaseApp;
    private FirestoreChangeListener? _acknowledgementListener;
    
    // Track last notification time per alert (for throttling)
    private readonly ConcurrentDictionary<string, DateTime> _lastNotificationTime = new();
    
    // Track notification count per alert
    private readonly ConcurrentDictionary<string, int> _notificationCount = new();
    
    private bool _isInitialized = false;
    private bool _isRunning = false;

    public NotificationAdapterService(
        ILogger<NotificationAdapterService> logger,
        FirebaseConfiguration config,
        AlertEngineService alertEngine)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _config = config ?? throw new ArgumentNullException(nameof(config));
        _alertEngine = alertEngine ?? throw new ArgumentNullException(nameof(alertEngine));
    }

    /// <summary>
    /// Starts the notification adapter service.
    /// Initializes Firebase, subscribes to alert events, starts acknowledgement listener.
    /// </summary>
    public async Task StartAsync()
    {
        if (!_config.Enabled)
        {
            _logger.LogInformation("Firebase notification adapter is disabled in configuration");
            return;
        }

        try
        {
            _logger.LogInformation("Starting Firebase Notification Adapter...");

            // Validate configuration
            _config.Validate();

            // Initialize Firebase
            await InitializeFirebaseAsync();

            // Subscribe to alert engine events
            SubscribeToAlertEvents();

            // Start acknowledgement listener (if enabled)
            if (_config.EnableAcknowledgementSync)
            {
                StartAcknowledgementListener();
            }

            _isRunning = true;
            _logger.LogInformation("Firebase Notification Adapter started successfully");
            _logger.LogInformation($"  Project ID: {_config.ProjectId}");
            _logger.LogInformation($"  Active Alerts Collection: {_config.ActiveAlertsCollection}");
            _logger.LogInformation($"  Notification Topic: {_config.NotificationTopic}");
            _logger.LogInformation($"  Acknowledgement Sync: {_config.EnableAcknowledgementSync}");
        }
        catch (Exception ex)
        {
            // CRITICAL: Never crash the service due to Firebase initialization failure
            _logger.LogError(ex, "Failed to start Firebase Notification Adapter. Service will continue without cloud sync.");
        }
    }

    /// <summary>
    /// Stops the notification adapter service gracefully.
    /// </summary>
    public async Task StopAsync()
    {
        if (!_config.Enabled || !_isRunning)
            return;

        try
        {
            _logger.LogInformation("Stopping Firebase Notification Adapter...");

            _isRunning = false;

            // Unsubscribe from alert events
            UnsubscribeFromAlertEvents();

            // Stop real-time listener
            if (_acknowledgementListener != null)
            {
                await _acknowledgementListener.StopAsync();
                _acknowledgementListener = null;
            }

            _logger.LogInformation("Firebase Notification Adapter stopped");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error stopping Firebase Notification Adapter");
        }
    }

    /// <summary>
    /// Initializes Firebase Admin SDK and Firestore client.
    /// </summary>
    private async Task InitializeFirebaseAsync()
    {
        try
        {
            // Load service account credentials
            var credential = GoogleCredential.FromFile(_config.ServiceAccountJsonPath);

            // Initialize Firebase App (if not already initialized)
            if (FirebaseApp.DefaultInstance == null)
            {
                _firebaseApp = FirebaseApp.Create(new AppOptions()
                {
                    Credential = credential,
                    ProjectId = _config.ProjectId
                });
                _logger.LogInformation("Firebase App initialized");
            }
            else
            {
                _firebaseApp = FirebaseApp.DefaultInstance;
                _logger.LogInformation("Using existing Firebase App instance");
            }

            // Initialize Firestore client
            _firestoreDb = await FirestoreDb.CreateAsync(_config.ProjectId);
            _logger.LogInformation("Firestore client initialized");

            _isInitialized = true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to initialize Firebase");
            throw;
        }
    }

    /// <summary>
    /// Subscribes to alert engine events.
    /// </summary>
    private void SubscribeToAlertEvents()
    {
        _alertEngine.AlertRaised += OnAlertRaised;
        _alertEngine.AlertCleared += OnAlertCleared;
        _alertEngine.AlertEscalated += OnAlertEscalated;
        
        _logger.LogInformation("Subscribed to alert engine events");
    }

    /// <summary>
    /// Unsubscribes from alert engine events.
    /// </summary>
    private void UnsubscribeFromAlertEvents()
    {
        _alertEngine.AlertRaised -= OnAlertRaised;
        _alertEngine.AlertCleared -= OnAlertCleared;
        _alertEngine.AlertEscalated -= OnAlertEscalated;
        
        _logger.LogInformation("Unsubscribed from alert engine events");
    }

    /// <summary>
    /// Handles AlertRaised event from alert engine.
    /// CRITICAL: This method MUST NOT block the alert engine thread.
    /// </summary>
    private void OnAlertRaised(object? sender, ActiveAlert alert)
    {
        if (!_isInitialized || !_isRunning)
            return;

        // Fire and forget - async operation runs in background
        _ = Task.Run(async () =>
        {
            try
            {
                if (_config.VerboseLogging)
                {
                    _logger.LogInformation($"Processing AlertRaised: {alert.Rule.RuleId}");
                }

                // Sync to Firestore (active alerts collection)
                await SyncAlertToFirestoreAsync(alert, isActive: true);

                // Send push notification (if configured for this severity)
                if (ShouldSendNotification(alert))
                {
                    await SendPushNotificationAsync(alert, "Alert Raised");
                }

                // Log event to audit trail (optional)
                await LogAlertEventAsync(alert, "Raised");
            }
            catch (Exception ex)
            {
                // CRITICAL: Never let exceptions propagate to alert engine
                _logger.LogError(ex, $"Error processing AlertRaised for {alert.Rule.RuleId}");
            }
        });
    }

    /// <summary>
    /// Handles AlertCleared event from alert engine.
    /// </summary>
    private void OnAlertCleared(object? sender, ActiveAlert alert)
    {
        if (!_isInitialized || !_isRunning)
            return;

        _ = Task.Run(async () =>
        {
            try
            {
                if (_config.VerboseLogging)
                {
                    _logger.LogInformation($"Processing AlertCleared: {alert.Rule.RuleId}");
                }

                // Move from active to history collection
                await MoveAlertToHistoryAsync(alert);

                // Clean up tracking dictionaries
                _lastNotificationTime.TryRemove(alert.Rule.RuleId, out _);
                _notificationCount.TryRemove(alert.Rule.RuleId, out _);

                // Log event to audit trail
                await LogAlertEventAsync(alert, "Cleared");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error processing AlertCleared for {alert.Rule.RuleId}");
            }
        });
    }

    /// <summary>
    /// Handles AlertEscalated event from alert engine.
    /// </summary>
    private void OnAlertEscalated(object? sender, ActiveAlert alert)
    {
        if (!_isInitialized || !_isRunning)
            return;

        _ = Task.Run(async () =>
        {
            try
            {
                if (_config.VerboseLogging)
                {
                    _logger.LogInformation($"Processing AlertEscalated: {alert.Rule.RuleId}");
                }

                // Update Firestore (increment escalation count)
                await SyncAlertToFirestoreAsync(alert, isActive: true);

                // ALWAYS send notification on escalation (critical event)
                await SendPushNotificationAsync(alert, "Alert Escalated");

                // Log event to audit trail
                await LogAlertEventAsync(alert, "Escalated");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error processing AlertEscalated for {alert.Rule.RuleId}");
            }
        });
    }

    /// <summary>
    /// Synchronizes an alert to Firestore (active alerts collection).
    /// Uses upsert (set with merge) to handle create/update.
    /// </summary>
    private async Task SyncAlertToFirestoreAsync(ActiveAlert alert, bool isActive)
    {
        if (_firestoreDb == null)
            return;

        await RetryWithBackoffAsync(async () =>
        {
            var collection = isActive ? _config.ActiveAlertsCollection : _config.HistoryAlertsCollection;
            var docRef = _firestoreDb.Collection(collection).Document(alert.Rule.RuleId);

            var firestoreDoc = FirestoreAlertDocument.FromActiveAlert(alert);

            // Add notification tracking metadata
            if (_lastNotificationTime.TryGetValue(alert.Rule.RuleId, out var lastNotif))
            {
                firestoreDoc.LastNotificationTime = Timestamp.FromDateTime(lastNotif.ToUniversalTime());
            }
            if (_notificationCount.TryGetValue(alert.Rule.RuleId, out var count))
            {
                firestoreDoc.NotificationCount = count;
            }

            await docRef.SetAsync(firestoreDoc, SetOptions.MergeAll);

            _logger.LogInformation($"Synced alert to Firestore: {alert.Rule.RuleId} ({collection})");
        }, $"Sync alert {alert.Rule.RuleId} to Firestore");
    }

    /// <summary>
    /// Moves an alert from active collection to history collection.
    /// </summary>
    private async Task MoveAlertToHistoryAsync(ActiveAlert alert)
    {
        if (_firestoreDb == null)
            return;

        await RetryWithBackoffAsync(async () =>
        {
            var activeDocRef = _firestoreDb.Collection(_config.ActiveAlertsCollection).Document(alert.Rule.RuleId);
            var historyDocRef = _firestoreDb.Collection(_config.HistoryAlertsCollection).Document(alert.Rule.RuleId);

            var firestoreDoc = FirestoreAlertDocument.FromActiveAlert(alert);

            // Write to history collection
            await historyDocRef.SetAsync(firestoreDoc);

            // Delete from active collection
            await activeDocRef.DeleteAsync();

            _logger.LogInformation($"Moved alert to history: {alert.Rule.RuleId}");
        }, $"Move alert {alert.Rule.RuleId} to history");
    }

    /// <summary>
    /// Logs an alert event to the audit trail collection.
    /// </summary>
    private async Task LogAlertEventAsync(ActiveAlert alert, string eventType)
    {
        if (_firestoreDb == null)
            return;

        try
        {
            var eventDoc = new FirestoreAlertEvent
            {
                AlertId = alert.Rule.RuleId,
                EventType = eventType,
                Timestamp = Timestamp.FromDateTime(DateTime.UtcNow),
                Severity = alert.Rule.Severity.ToString(),
                Message = alert.Message,
                Value = alert.TriggerValue,
                TriggeredBy = "ScadaWatcherService"
            };

            var eventRef = _firestoreDb.Collection(_config.EventsCollection).Document(eventDoc.EventId);
            await eventRef.SetAsync(eventDoc);

            if (_config.VerboseLogging)
            {
                _logger.LogDebug($"Logged alert event: {eventType} for {alert.Rule.RuleId}");
            }
        }
        catch (Exception ex)
        {
            // Non-critical: Audit trail failure should not block main flow
            _logger.LogWarning(ex, $"Failed to log alert event: {eventType} for {alert.Rule.RuleId}");
        }
    }

    /// <summary>
    /// Sends a push notification via Firebase Cloud Messaging.
    /// Respects notification throttling to prevent spam.
    /// </summary>
    private async Task SendPushNotificationAsync(ActiveAlert alert, string notificationType)
    {
        try
        {
            // Check throttling
            if (!IsNotificationAllowed(alert.Rule.RuleId))
            {
                _logger.LogInformation($"Notification suppressed (throttled): {alert.Rule.RuleId}");
                return;
            }

            var message = new Message()
            {
                Topic = _config.NotificationTopic,
                Notification = new Notification()
                {
                    Title = $"{alert.Rule.Severity} Alert: {alert.Rule.Description}",
                    Body = alert.Message
                },
                Data = new Dictionary<string, string>()
                {
                    { "alertId", alert.Rule.RuleId },
                    { "nodeId", alert.Rule.NodeId },
                    { "severity", alert.Rule.Severity.ToString() },
                    { "state", alert.State.ToString() },
                    { "type", notificationType },
                    { "timestamp", DateTime.UtcNow.ToString("o") }
                },
                Android = new AndroidConfig()
                {
                    Priority = Priority.High, // Force High Priority for best latency
                    Notification = new AndroidNotification()
                    {
                        Sound = alert.Rule.Severity == AlertSeverity.Critical ? "critical_alarm" : "default",
                        ChannelId = alert.Rule.Severity == AlertSeverity.Critical ? "critical_alerts" : "alerts"
                    }
                },
                Apns = new ApnsConfig()
                {
                    Aps = new Aps()
                    {
                        Sound = alert.Rule.Severity == AlertSeverity.Critical ? "critical_alarm.wav" : "default"
                    }
                }
            };

            await RetryWithBackoffAsync(async () =>
            {
                var response = await FirebaseMessaging.DefaultInstance.SendAsync(message);
                _logger.LogInformation($"Push notification sent: {alert.Rule.RuleId} (MessageId: {response})");
            }, $"Send push notification for {alert.Rule.RuleId}");

            // Update throttling tracking
            _lastNotificationTime[alert.Rule.RuleId] = DateTime.UtcNow;
            _notificationCount.AddOrUpdate(alert.Rule.RuleId, 1, (key, oldValue) => oldValue + 1);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Failed to send push notification for {alert.Rule.RuleId}");
        }
    }

    /// <summary>
    /// Determines if a notification should be sent based on severity configuration.
    /// </summary>
    private bool ShouldSendNotification(ActiveAlert alert)
    {
        return alert.Rule.Severity switch
        {
            AlertSeverity.Info => _config.SendNotificationsForInfo,
            AlertSeverity.Warning => _config.SendNotificationsForWarning,
            AlertSeverity.Critical => _config.SendNotificationsForCritical,
            _ => false
        };
    }

    /// <summary>
    /// Checks if a notification is allowed (throttling check).
    /// </summary>
    private bool IsNotificationAllowed(string alertId)
    {
        if (!_lastNotificationTime.TryGetValue(alertId, out var lastTime))
            return true;

        var elapsed = (DateTime.UtcNow - lastTime).TotalSeconds;
        return elapsed >= _config.NotificationThrottleSeconds;
    }

    /// <summary>
    /// Starts the Firestore acknowledgement listener using real-time snapshots (Listen).
    /// This provides the lowest possible latency for sync-back.
    /// </summary>
    private void StartAcknowledgementListener()
    {
        if (_firestoreDb == null)
            return;

        try
        {
            _logger.LogInformation("Starting real-time Firestore acknowledgement listener...");

            Query query = _firestoreDb.Collection(_config.ActiveAlertsCollection)
                .WhereNotEqualTo("acknowledgedTime", null);

            _acknowledgementListener = query.Listen(snapshot =>
            {
                foreach (var change in snapshot.Changes)
                {
                    if (change.ChangeType == DocumentChange.Type.Added || 
                        change.ChangeType == DocumentChange.Type.Modified)
                    {
                        try
                        {
                            var alert = change.Document.ConvertTo<FirestoreAlertDocument>();
                            
                            if (alert.AcknowledgedTime.HasValue)
                            {
                                var acknowledged = _alertEngine.AcknowledgeAlert(alert.AlertId);
                                if (acknowledged)
                                {
                                    _logger.LogInformation($"Real-time sync: Alert {alert.AlertId} acknowledged by {alert.AcknowledgedBy ?? "unknown"}");
                                }
                            }
                        }
                        catch (Exception ex)
                        {
                            _logger.LogWarning(ex, "Error processing real-time acknowledgement change");
                        }
                    }
                }
            });

            _logger.LogInformation("Real-time Firestore acknowledgement listener active");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to start real-time acknowledgement listener");
        }
    }

    /// <summary>
    /// Retries an async operation with exponential backoff.
    /// </summary>
    private async Task RetryWithBackoffAsync(Func<Task> operation, string operationName)
    {
        int attempt = 0;
        while (attempt < _config.MaxRetryAttempts)
        {
            try
            {
                await operation();
                return; // Success
            }
            catch (Exception ex)
            {
                attempt++;
                if (attempt >= _config.MaxRetryAttempts)
                {
                    _logger.LogError(ex, $"Failed to {operationName} after {attempt} attempts");
                    throw;
                }

                var delaySeconds = _config.RetryIntervalsSeconds[Math.Min(attempt - 1, _config.RetryIntervalsSeconds.Length - 1)];
                _logger.LogWarning(ex, $"Failed to {operationName} (attempt {attempt}/{_config.MaxRetryAttempts}). Retrying in {delaySeconds}s...");
                await Task.Delay(TimeSpan.FromSeconds(delaySeconds));
            }
        }
    }

    /// <summary>
    /// Gets statistics about notification activity.
    /// </summary>
    public (int TotalNotificationsSent, int ThrottledAlerts) GetStatistics()
    {
        var totalSent = _notificationCount.Values.Sum();
        var throttled = _lastNotificationTime.Count;
        return (totalSent, throttled);
    }
}
