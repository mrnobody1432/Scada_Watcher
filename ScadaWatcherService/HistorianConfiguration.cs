namespace ScadaWatcherService;

/// <summary>
/// Configuration model for SQLite historian service.
/// Designed for industrial SCADA data persistence with performance and reliability focus.
/// Loaded from appsettings.json to support external configuration without code changes.
/// </summary>
public class HistorianConfiguration
{
    /// <summary>
    /// Enable or disable the historian service.
    /// Set to false to run service without data persistence (OPC UA + Flutter only).
    /// </summary>
    public bool Enabled { get; set; } = true;

    /// <summary>
    /// Full path to the SQLite database file.
    /// Directory will be created automatically if it does not exist.
    /// Example: "C:\\SCADA\\Data\\historian.db"
    /// Recommended: Use dedicated data partition with sufficient space.
    /// </summary>
    public string DatabasePath { get; set; } = "C:\\SCADA\\Data\\historian.db";

    /// <summary>
    /// Number of data points to batch before writing to database.
    /// Higher values improve write performance but increase memory usage.
    /// Lower values reduce memory but increase write frequency.
    /// Recommended: 100-1000 for typical SCADA applications.
    /// </summary>
    public int BatchSize { get; set; } = 500;

    /// <summary>
    /// Maximum time in milliseconds before flushing pending data to database.
    /// Ensures data is persisted even if batch size is not reached.
    /// Lower values reduce potential data loss, higher values improve performance.
    /// Recommended: 1000-5000 (1-5 seconds) for industrial applications.
    /// </summary>
    public int FlushIntervalMs { get; set; } = 2000;

    /// <summary>
    /// Maximum number of data points to queue in memory before blocking.
    /// Prevents unbounded memory growth during burst data scenarios.
    /// When queue is full, oldest data is dropped with warning.
    /// Recommended: 10000-100000 depending on available memory.
    /// </summary>
    public int MaxQueueSize { get; set; } = 50000;

    /// <summary>
    /// Number of retry attempts for database operations before giving up.
    /// SQLite may temporarily lock during heavy load or backups.
    /// Recommended: 3-5 retries for production reliability.
    /// </summary>
    public int MaxRetryAttempts { get; set; } = 5;

    /// <summary>
    /// Delay in milliseconds between retry attempts.
    /// Allows time for database locks to release.
    /// Recommended: 100-500 ms.
    /// </summary>
    public int RetryDelayMs { get; set; } = 200;

    /// <summary>
    /// SQLite busy timeout in milliseconds.
    /// How long SQLite will wait for locks before returning SQLITE_BUSY.
    /// Recommended: 5000-30000 (5-30 seconds) for industrial use.
    /// </summary>
    public int BusyTimeoutMs { get; set; } = 10000;

    /// <summary>
    /// Number of days to retain historical data.
    /// Data older than this will be deleted during maintenance.
    /// 0 = disable automatic cleanup (manual maintenance required).
    /// Recommended: 30-365 days depending on compliance requirements.
    /// </summary>
    public int RetentionDays { get; set; } = 90;

    /// <summary>
    /// Enable periodic database maintenance (VACUUM, ANALYZE).
    /// Improves query performance and reclaims disk space.
    /// Should be enabled for long-running production systems.
    /// </summary>
    public bool EnableMaintenance { get; set; } = true;

    /// <summary>
    /// Interval in hours between maintenance operations.
    /// Maintenance is performed during low-activity periods.
    /// Recommended: 24 hours (daily maintenance).
    /// </summary>
    public int MaintenanceIntervalHours { get; set; } = 24;

    /// <summary>
    /// Enable Write-Ahead Logging (WAL) mode for SQLite.
    /// CRITICAL: WAL mode improves concurrency and crash recovery.
    /// Should always be enabled for production SCADA systems.
    /// </summary>
    public bool EnableWalMode { get; set; } = true;

    /// <summary>
    /// SQLite cache size in KB.
    /// Larger cache improves performance but uses more memory.
    /// Recommended: 10000-100000 (10-100 MB) for industrial applications.
    /// </summary>
    public int CacheSizeKB { get; set; } = 20000;

    /// <summary>
    /// Enable detailed logging of historian operations.
    /// Logs every batch write, maintenance, and error.
    /// Disable in production if log volume is too high.
    /// </summary>
    public bool VerboseLogging { get; set; } = false;
}
