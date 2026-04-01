namespace ScadaWatcherService;

/// <summary>
/// Configuration model for OPC UA client connection and data acquisition.
/// Loaded from appsettings.json to support external configuration without code changes.
/// Designed for industrial SCADA environments with security and reliability requirements.
/// </summary>
public class OpcUaConfiguration
{
    /// <summary>
    /// Enable or disable OPC UA data collection.
    /// Set to false to run service without OPC UA (Flutter watchdog only).
    /// </summary>
    public bool Enabled { get; set; } = false;

    /// <summary>
    /// OPC UA server endpoint URL.
    /// Format: opc.tcp://hostname:port/path
    /// Example: "opc.tcp://192.168.1.100:4840/UA/Server"
    /// </summary>
    public string EndpointUrl { get; set; } = string.Empty;

    /// <summary>
    /// Security mode for OPC UA connection.
    /// Options: "None" (insecure), "Sign", "SignAndEncrypt"
    /// Production: Use "SignAndEncrypt"
    /// Testing: Can use "None" for initial setup
    /// </summary>
    public string SecurityMode { get; set; } = "None";

    /// <summary>
    /// Security policy URI.
    /// Options: 
    ///   - "" or "None" (no security)
    ///   - "Basic256Sha256" (recommended for production)
    ///   - "Aes128_Sha256_RsaOaep"
    ///   - "Aes256_Sha256_RsaPss"
    /// </summary>
    public string SecurityPolicy { get; set; } = "None";

    /// <summary>
    /// Authentication mode.
    /// Options: "Anonymous", "UsernamePassword"
    /// </summary>
    public string AuthenticationMode { get; set; } = "Anonymous";

    /// <summary>
    /// Username for authentication (if AuthenticationMode = "UsernamePassword").
    /// Leave empty for anonymous connections.
    /// </summary>
    public string Username { get; set; } = string.Empty;

    /// <summary>
    /// Password for authentication (if AuthenticationMode = "UsernamePassword").
    /// SECURITY: Consider using environment variables or encrypted storage.
    /// </summary>
    public string Password { get; set; } = string.Empty;

    /// <summary>
    /// Application name for OPC UA client identification.
    /// Appears in server logs and audit trails.
    /// </summary>
    public string ApplicationName { get; set; } = "SCADA Watcher OPC UA Client";

    /// <summary>
    /// Application URI for OPC UA client.
    /// Must be unique and match certificate if using secure mode.
    /// Format: urn:hostname:application
    /// </summary>
    public string ApplicationUri { get; set; } = "urn:ScadaWatcher:OpcUaClient";

    /// <summary>
    /// Session timeout in milliseconds.
    /// Server will close session if no activity for this duration.
    /// Recommended: 30000-60000 (30-60 seconds)
    /// </summary>
    public int SessionTimeoutMs { get; set; } = 60000;

    /// <summary>
    /// Keep-alive interval in milliseconds.
    /// Client sends keep-alive messages to maintain session.
    /// Recommended: 5000-10000 (5-10 seconds)
    /// </summary>
    public int KeepAliveIntervalMs { get; set; } = 10000;

    /// <summary>
    /// Delay in seconds before attempting to reconnect after connection loss.
    /// Initial delay - increases exponentially on repeated failures.
    /// </summary>
    public int ReconnectDelaySeconds { get; set; } = 10;

    /// <summary>
    /// Maximum reconnect delay in seconds for exponential backoff.
    /// Caps the maximum wait time between reconnection attempts.
    /// </summary>
    public int MaxReconnectDelaySeconds { get; set; } = 300;

    /// <summary>
    /// Publishing interval in milliseconds for subscription.
    /// How often the server checks monitored items for changes.
    /// Lower = more responsive, higher CPU usage
    /// Recommended: 1000-5000 (1-5 seconds) for SCADA
    /// </summary>
    public int PublishingIntervalMs { get; set; } = 1000;

    /// <summary>
    /// Sampling interval in milliseconds for monitored items.
    /// How often the server samples the data source.
    /// 0 = use fastest rate available
    /// Recommended: Match or slightly less than PublishingInterval
    /// </summary>
    public int SamplingIntervalMs { get; set; } = 1000;

    /// <summary>
    /// Queue size for each monitored item.
    /// Number of data changes buffered before oldest is discarded.
    /// Recommended: 1 for real-time data, 10+ for historical buffering
    /// </summary>
    public int QueueSize { get; set; } = 10;

    /// <summary>
    /// Accept untrusted server certificates.
    /// WARNING: Only enable for testing! Production must use false.
    /// </summary>
    public bool AcceptUntrustedCertificates { get; set; } = false;

    /// <summary>
    /// Auto-accept all server certificates without validation.
    /// WARNING: Only enable for testing! Production must use false.
    /// </summary>
    public bool AutoAcceptCertificates { get; set; } = false;

    /// <summary>
    /// List of OPC UA node identifiers to monitor.
    /// Each node will be subscribed for data change notifications.
    /// Format depends on node identifier type:
    ///   - Numeric: "ns=2;i=1001"
    ///   - String: "ns=2;s=Temperature.Sensor1"
    ///   - GUID: "ns=2;g=550e8400-e29b-41d4-a716-446655440000"
    /// </summary>
    public List<OpcUaNodeConfiguration> Nodes { get; set; } = new List<OpcUaNodeConfiguration>();
}

/// <summary>
/// Configuration for individual OPC UA nodes to monitor.
/// Supports deadband filtering and custom sampling rates per node.
/// </summary>
public class OpcUaNodeConfiguration
{
    /// <summary>
    /// OPC UA Node Identifier.
    /// Examples:
    ///   - "ns=2;i=1001" (numeric)
    ///   - "ns=2;s=Device.Temperature" (string)
    ///   - "ns=3;s=PLC1.Tags.Pressure"
    /// </summary>
    public string NodeId { get; set; } = string.Empty;

    /// <summary>
    /// Friendly name for logging and identification.
    /// Used in log messages and data structures.
    /// </summary>
    public string DisplayName { get; set; } = string.Empty;

    /// <summary>
    /// Override sampling interval for this specific node (milliseconds).
    /// 0 or null = use global SamplingIntervalMs
    /// </summary>
    public int? SamplingIntervalMs { get; set; }

    /// <summary>
    /// Deadband filter type for numeric values.
    /// Options: "None", "Absolute", "Percent"
    /// Prevents notification for minor value fluctuations.
    /// </summary>
    public string DeadbandType { get; set; } = "None";

    /// <summary>
    /// Deadband value.
    /// - Absolute: Minimum change required (e.g., 0.5 for ±0.5 units)
    /// - Percent: Minimum percentage change (e.g., 1.0 for ±1%)
    /// </summary>
    public double DeadbandValue { get; set; } = 0.0;
}
