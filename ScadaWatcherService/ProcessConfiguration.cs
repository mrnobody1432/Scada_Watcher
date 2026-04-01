namespace ScadaWatcherService;

/// <summary>
/// Configuration model for managed process settings.
/// Loaded from appsettings.json to support external configuration without code changes.
/// </summary>
public class ProcessConfiguration
{
    /// <summary>
    /// Full path to the Flutter executable to be managed.
    /// Example: "C:\\SCADA\\FlutterApp\\app.exe"
    /// </summary>
    public string ExecutablePath { get; set; } = string.Empty;

    /// <summary>
    /// Command-line arguments to pass to the Flutter executable.
    /// Leave empty if no arguments are required.
    /// </summary>
    public string Arguments { get; set; } = string.Empty;

    /// <summary>
    /// Working directory for the Flutter process.
    /// If empty, uses the directory containing the executable.
    /// </summary>
    public string WorkingDirectory { get; set; } = string.Empty;

    /// <summary>
    /// Delay in seconds before starting the Flutter process after service starts.
    /// Allows time for Windows networking and system services to initialize.
    /// Recommended: 10-30 seconds for SCADA environments.
    /// </summary>
    public int StartupDelaySeconds { get; set; } = 15;

    /// <summary>
    /// Interval in seconds between process health checks.
    /// Lower values = faster crash detection, higher CPU usage.
    /// Recommended: 5-10 seconds for critical applications.
    /// </summary>
    public int MonitoringIntervalSeconds { get; set; } = 5;

    /// <summary>
    /// Delay in seconds before restarting a crashed process.
    /// Prevents rapid restart loops and allows resources to be released.
    /// Increases exponentially on repeated failures.
    /// </summary>
    public int RestartDelaySeconds { get; set; } = 10;

    /// <summary>
    /// Maximum restart delay in seconds for exponential backoff.
    /// Caps the maximum wait time between restart attempts.
    /// </summary>
    public int MaxRestartDelaySeconds { get; set; } = 300;

    /// <summary>
    /// Time in milliseconds to wait for graceful process shutdown.
    /// If exceeded, the process will be forcefully terminated.
    /// </summary>
    public int ShutdownTimeoutMs { get; set; } = 5000;

    /// <summary>
    /// Enable headless mode for the Flutter application.
    /// When true, creates the process without a visible window.
    /// </summary>
    public bool HeadlessMode { get; set; } = true;

    /// <summary>
    /// Enable process monitoring and auto-restart.
    /// Set to false for maintenance mode.
    /// </summary>
    public bool AutoRestart { get; set; } = true;
}

/// <summary>
/// Configuration model for logging settings.
/// </summary>
public class LoggingConfiguration
{
    /// <summary>
    /// Directory where log files will be stored.
    /// Example: "C:\\Logs\\ScadaWatcher"
    /// </summary>
    public string LogDirectory { get; set; } = "C:\\Logs\\ScadaWatcher";

    /// <summary>
    /// Maximum size of a single log file in MB before rotation.
    /// </summary>
    public int FileSizeLimitMB { get; set; } = 50;

    /// <summary>
    /// Number of log files to retain before deleting oldest.
    /// </summary>
    public int RetainedFileCount { get; set; } = 30;
}
