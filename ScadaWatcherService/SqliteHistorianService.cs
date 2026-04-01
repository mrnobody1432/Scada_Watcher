using System.Collections.Concurrent;
using System.Data;
using System.Diagnostics;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.Options;

namespace ScadaWatcherService;

/// <summary>
/// Production-grade SQLite historian service for industrial SCADA data persistence.
/// Implements high-performance batched writes, automatic schema management, and robust error handling.
/// Designed for continuous multi-year operation with millions of data points.
/// 
/// Key Features:
/// - Non-blocking OPC UA data ingestion via lock-free queue
/// - Batched writes with configurable size and flush interval
/// - WAL mode for concurrent access and crash recovery
/// - Automatic schema creation and migration
/// - Retry logic for transient database locks
/// - Graceful degradation on errors
/// - Comprehensive logging and diagnostics
/// - Zero impact on OPC UA client or Flutter watchdog
/// </summary>
public class SqliteHistorianService : IDisposable
{
    private readonly ILogger<SqliteHistorianService> _logger;
    private readonly HistorianConfiguration _config;

    // Lock-free concurrent queue for OPC UA data events
    private readonly ConcurrentQueue<OpcUaDataValue> _dataQueue;
    
    // Background writer task
    private Task? _writerTask;
    private CancellationTokenSource? _writerCts;
    
    // Maintenance task
    private Task? _maintenanceTask;
    
    // Database connection (dedicated for writer thread)
    private SqliteConnection? _connection;
    
    // State tracking
    private bool _isRunning = false;
    private bool _disposed = false;
    private long _totalWritten = 0;
    private long _totalDropped = 0;
    private DateTime _lastMaintenanceTime = DateTime.MinValue;

    // Diagnostics
    private readonly Stopwatch _flushStopwatch = new();

    public SqliteHistorianService(
        ILogger<SqliteHistorianService> logger,
        IOptions<HistorianConfiguration> config)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _config = config?.Value ?? throw new ArgumentNullException(nameof(config));
        _dataQueue = new ConcurrentQueue<OpcUaDataValue>();
    }

    /// <summary>
    /// Start the historian service and initialize database.
    /// Safe to call multiple times - will only start once.
    /// </summary>
    public async Task StartAsync(CancellationToken cancellationToken = default)
    {
        if (_isRunning)
        {
            _logger.LogWarning("Historian service is already running. Ignoring start request.");
            return;
        }

        if (!_config.Enabled)
        {
            _logger.LogInformation("Historian service is disabled in configuration. Not starting.");
            return;
        }

        _logger.LogInformation("=== SQLite Historian Service Starting ===");
        _logger.LogInformation("Database Path: {Path}", _config.DatabasePath);
        _logger.LogInformation("Batch Size: {Size}, Flush Interval: {Interval}ms", 
            _config.BatchSize, _config.FlushIntervalMs);
        _logger.LogInformation("Max Queue Size: {Size}", _config.MaxQueueSize);
        _logger.LogInformation("Retention Days: {Days}", _config.RetentionDays);

        try
        {
            // Ensure database directory exists
            EnsureDatabaseDirectory();

            // Open database connection
            await OpenDatabaseAsync();

            // Initialize schema
            await InitializeSchemaAsync();

            // Configure database for optimal performance
            await ConfigureDatabaseAsync();

            // Start background writer
            _writerCts = new CancellationTokenSource();
            _writerTask = Task.Run(() => WriterLoopAsync(_writerCts.Token), _writerCts.Token);

            // Start maintenance task if enabled
            if (_config.EnableMaintenance)
            {
                _maintenanceTask = Task.Run(() => MaintenanceLoopAsync(_writerCts.Token), _writerCts.Token);
            }

            _isRunning = true;
            _logger.LogInformation("SQLite Historian Service started successfully.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "CRITICAL: Failed to start historian service. Data will NOT be persisted.");
            // Service continues without historian - graceful degradation
        }
    }

    /// <summary>
    /// Stop the historian service and flush remaining data.
    /// </summary>
    public async Task StopAsync(CancellationToken cancellationToken = default)
    {
        if (!_isRunning)
        {
            return;
        }

        _logger.LogInformation("Historian service stopping...");
        _isRunning = false;

        try
        {
            // Signal writer to stop
            _writerCts?.Cancel();

            // Wait for writer to finish flushing
            if (_writerTask != null)
            {
                await Task.WhenAny(_writerTask, Task.Delay(10000, cancellationToken));
            }

            // Wait for maintenance to stop
            if (_maintenanceTask != null)
            {
                await Task.WhenAny(_maintenanceTask, Task.Delay(5000, cancellationToken));
            }

            _logger.LogInformation("Historian service stopped. Total written: {Total}, Total dropped: {Dropped}",
                _totalWritten, _totalDropped);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during historian shutdown.");
        }
    }

    /// <summary>
    /// Enqueue OPC UA data point for persistence.
    /// Non-blocking - returns immediately.
    /// Called from OPC UA callback thread - MUST be fast.
    /// </summary>
    public void EnqueueDataPoint(OpcUaDataValue dataPoint)
    {
        if (!_isRunning || dataPoint == null)
        {
            return;
        }

        try
        {
            // Check queue size to prevent unbounded growth
            if (_dataQueue.Count >= _config.MaxQueueSize)
            {
                _totalDropped++;
                
                if (_totalDropped % 1000 == 1) // Log every 1000 drops
                {
                    _logger.LogWarning(
                        "Historian queue full ({Size}). Dropping data point: {NodeId}. Total dropped: {Total}",
                        _config.MaxQueueSize, dataPoint.NodeId, _totalDropped);
                }
                return;
            }

            // Enqueue (lock-free, non-blocking)
            _dataQueue.Enqueue(dataPoint);
        }
        catch (Exception ex)
        {
            // CRITICAL: Never throw from enqueue method
            _logger.LogError(ex, "Error enqueueing data point for {NodeId}", dataPoint.NodeId);
        }
    }

    /// <summary>
    /// Ensure database directory exists.
    /// </summary>
    private void EnsureDatabaseDirectory()
    {
        try
        {
            var directory = Path.GetDirectoryName(_config.DatabasePath);
            if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
                _logger.LogInformation("Created database directory: {Directory}", directory);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to create database directory");
            throw;
        }
    }

    /// <summary>
    /// Open SQLite database connection with optimal settings.
    /// </summary>
    private async Task OpenDatabaseAsync()
    {
        try
        {
            var connectionString = new SqliteConnectionStringBuilder
            {
                DataSource = _config.DatabasePath,
                Mode = SqliteOpenMode.ReadWriteCreate,
                Cache = SqliteCacheMode.Shared
            }.ToString();

            _connection = new SqliteConnection(connectionString);
            await _connection.OpenAsync();

            _logger.LogInformation("Database connection opened: {Path}", _config.DatabasePath);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to open database connection");
            throw;
        }
    }

    /// <summary>
    /// Configure SQLite database for optimal performance and reliability.
    /// </summary>
    private async Task ConfigureDatabaseAsync()
    {
        if (_connection == null || _connection.State != ConnectionState.Open)
        {
            throw new InvalidOperationException("Database connection is not open");
        }

        try
        {
            using var cmd = _connection.CreateCommand();

            // Enable WAL mode for better concurrency and crash recovery
            if (_config.EnableWalMode)
            {
                cmd.CommandText = "PRAGMA journal_mode=WAL;";
                var result = await cmd.ExecuteScalarAsync();
                _logger.LogInformation("WAL mode enabled: {Result}", result);
            }

            // Set busy timeout to handle locks gracefully
            cmd.CommandText = $"PRAGMA busy_timeout={_config.BusyTimeoutMs};";
            await cmd.ExecuteNonQueryAsync();

            // Configure cache size for better performance
            cmd.CommandText = $"PRAGMA cache_size=-{_config.CacheSizeKB};";
            await cmd.ExecuteNonQueryAsync();

            // Enable foreign keys for data integrity
            cmd.CommandText = "PRAGMA foreign_keys=ON;";
            await cmd.ExecuteNonQueryAsync();

            // Synchronous mode: NORMAL for WAL (balance between safety and performance)
            cmd.CommandText = "PRAGMA synchronous=NORMAL;";
            await cmd.ExecuteNonQueryAsync();

            // Temp store in memory for better performance
            cmd.CommandText = "PRAGMA temp_store=MEMORY;";
            await cmd.ExecuteNonQueryAsync();

            _logger.LogInformation("Database configured for optimal performance.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to configure database");
            throw;
        }
    }

    /// <summary>
    /// Initialize database schema.
    /// Creates tables and indexes if they don't exist.
    /// Designed for industrial historian use with normalized schema.
    /// </summary>
    private async Task InitializeSchemaAsync()
    {
        if (_connection == null || _connection.State != ConnectionState.Open)
        {
            throw new InvalidOperationException("Database connection is not open");
        }

        try
        {
            _logger.LogInformation("Initializing database schema...");

            using var cmd = _connection.CreateCommand();

            // Create data_points table for time-series data
            cmd.CommandText = @"
                CREATE TABLE IF NOT EXISTS data_points (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    node_id TEXT NOT NULL,
                    display_name TEXT NOT NULL,
                    source_timestamp INTEGER NOT NULL,
                    received_timestamp INTEGER NOT NULL,
                    value_numeric REAL,
                    value_text TEXT,
                    value_boolean INTEGER,
                    data_type TEXT NOT NULL,
                    status_code INTEGER NOT NULL,
                    status_description TEXT NOT NULL,
                    is_good_quality INTEGER NOT NULL
                );";
            await cmd.ExecuteNonQueryAsync();

            // Create index on source_timestamp for time-range queries
            cmd.CommandText = @"
                CREATE INDEX IF NOT EXISTS idx_data_points_timestamp 
                ON data_points(source_timestamp DESC);";
            await cmd.ExecuteNonQueryAsync();

            // Create index on node_id for tag-based queries
            cmd.CommandText = @"
                CREATE INDEX IF NOT EXISTS idx_data_points_node_id 
                ON data_points(node_id);";
            await cmd.ExecuteNonQueryAsync();

            // Create composite index for common query patterns (tag + time range)
            cmd.CommandText = @"
                CREATE INDEX IF NOT EXISTS idx_data_points_node_time 
                ON data_points(node_id, source_timestamp DESC);";
            await cmd.ExecuteNonQueryAsync();

            // Create index on data quality for filtering bad data
            cmd.CommandText = @"
                CREATE INDEX IF NOT EXISTS idx_data_points_quality 
                ON data_points(is_good_quality);";
            await cmd.ExecuteNonQueryAsync();

            // Create metadata table for tags/nodes
            cmd.CommandText = @"
                CREATE TABLE IF NOT EXISTS tag_metadata (
                    node_id TEXT PRIMARY KEY,
                    display_name TEXT NOT NULL,
                    data_type TEXT,
                    description TEXT,
                    engineering_units TEXT,
                    min_value REAL,
                    max_value REAL,
                    first_seen INTEGER NOT NULL,
                    last_seen INTEGER NOT NULL,
                    sample_count INTEGER DEFAULT 0
                );";
            await cmd.ExecuteNonQueryAsync();

            // Create statistics table for monitoring
            cmd.CommandText = @"
                CREATE TABLE IF NOT EXISTS historian_stats (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp INTEGER NOT NULL,
                    total_points INTEGER NOT NULL,
                    total_dropped INTEGER NOT NULL,
                    database_size_mb REAL,
                    queue_size INTEGER
                );";
            await cmd.ExecuteNonQueryAsync();

            _logger.LogInformation("Database schema initialized successfully.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to initialize database schema");
            throw;
        }
    }

    /// <summary>
    /// Background writer loop.
    /// Continuously processes queued data points and writes them in batches.
    /// </summary>
    private async Task WriterLoopAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Historian writer loop started.");

        var batch = new List<OpcUaDataValue>(_config.BatchSize);
        _flushStopwatch.Start();

        while (!cancellationToken.IsCancellationRequested || !_dataQueue.IsEmpty)
        {
            try
            {
                // Collect batch or wait for flush interval
                while (batch.Count < _config.BatchSize && _flushStopwatch.ElapsedMilliseconds < _config.FlushIntervalMs)
                {
                    if (_dataQueue.TryDequeue(out var dataPoint))
                    {
                        batch.Add(dataPoint);
                    }
                    else if (batch.Count == 0)
                    {
                        // Queue empty, wait briefly
                        await Task.Delay(100, cancellationToken);
                        break;
                    }
                    else
                    {
                        // Have some data, wait for more
                        await Task.Delay(50, cancellationToken);
                    }
                }

                // Write batch if we have data and (batch full OR flush interval elapsed)
                if (batch.Count > 0 && (batch.Count >= _config.BatchSize || _flushStopwatch.ElapsedMilliseconds >= _config.FlushIntervalMs))
                {
                    await WriteBatchAsync(batch);
                    batch.Clear();
                    _flushStopwatch.Restart();
                }
            }
            catch (OperationCanceledException)
            {
                // Expected during shutdown
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in historian writer loop. Continuing...");
                await Task.Delay(1000, cancellationToken);
            }
        }

        // Final flush on shutdown
        if (batch.Count > 0)
        {
            try
            {
                _logger.LogInformation("Flushing {Count} remaining data points on shutdown...", batch.Count);
                await WriteBatchAsync(batch);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to flush remaining data on shutdown");
            }
        }

        _logger.LogInformation("Historian writer loop stopped.");
    }

    /// <summary>
    /// Write batch of data points to database with retry logic.
    /// Uses transaction for atomicity and performance.
    /// </summary>
    private async Task WriteBatchAsync(List<OpcUaDataValue> batch)
    {
        if (batch.Count == 0 || _connection == null)
        {
            return;
        }

        var attempt = 0;
        var stopwatch = Stopwatch.StartNew();

        while (attempt < _config.MaxRetryAttempts)
        {
            try
            {
                var transaction = (SqliteTransaction)await _connection.BeginTransactionAsync();
                using var cmd = _connection.CreateCommand();
                cmd.Transaction = transaction;

                // Prepare insert statement
                cmd.CommandText = @"
                    INSERT INTO data_points (
                        node_id, display_name, source_timestamp, received_timestamp,
                        value_numeric, value_text, value_boolean, data_type,
                        status_code, status_description, is_good_quality
                    ) VALUES (
                        $node_id, $display_name, $source_ts, $received_ts,
                        $value_numeric, $value_text, $value_boolean, $data_type,
                        $status_code, $status_desc, $is_good_quality
                    );";

                // Add parameters
                cmd.Parameters.Add("$node_id", SqliteType.Text);
                cmd.Parameters.Add("$display_name", SqliteType.Text);
                cmd.Parameters.Add("$source_ts", SqliteType.Integer);
                cmd.Parameters.Add("$received_ts", SqliteType.Integer);
                cmd.Parameters.Add("$value_numeric", SqliteType.Real);
                cmd.Parameters.Add("$value_text", SqliteType.Text);
                cmd.Parameters.Add("$value_boolean", SqliteType.Integer);
                cmd.Parameters.Add("$data_type", SqliteType.Text);
                cmd.Parameters.Add("$status_code", SqliteType.Integer);
                cmd.Parameters.Add("$status_desc", SqliteType.Text);
                cmd.Parameters.Add("$is_good_quality", SqliteType.Integer);

                await cmd.PrepareAsync();

                // Execute batch inserts
                foreach (var dataPoint in batch)
                {
                    cmd.Parameters["$node_id"].Value = dataPoint.NodeId;
                    cmd.Parameters["$display_name"].Value = dataPoint.DisplayName;
                    cmd.Parameters["$source_ts"].Value = new DateTimeOffset(dataPoint.SourceTimestamp).ToUnixTimeMilliseconds();
                    cmd.Parameters["$received_ts"].Value = new DateTimeOffset(dataPoint.ReceivedTimestamp).ToUnixTimeMilliseconds();
                    
                    // Store value based on type
                    if (dataPoint.TryGetDouble(out double numericValue))
                    {
                        cmd.Parameters["$value_numeric"].Value = numericValue;
                        cmd.Parameters["$value_text"].Value = DBNull.Value;
                        cmd.Parameters["$value_boolean"].Value = DBNull.Value;
                    }
                    else if (dataPoint.TryGetBoolean(out bool boolValue))
                    {
                        cmd.Parameters["$value_numeric"].Value = DBNull.Value;
                        cmd.Parameters["$value_text"].Value = DBNull.Value;
                        cmd.Parameters["$value_boolean"].Value = boolValue ? 1 : 0;
                    }
                    else
                    {
                        cmd.Parameters["$value_numeric"].Value = DBNull.Value;
                        cmd.Parameters["$value_text"].Value = dataPoint.ValueAsString;
                        cmd.Parameters["$value_boolean"].Value = DBNull.Value;
                    }

                    cmd.Parameters["$data_type"].Value = dataPoint.DataType;
                    cmd.Parameters["$status_code"].Value = dataPoint.StatusCode;
                    cmd.Parameters["$status_desc"].Value = dataPoint.StatusDescription;
                    cmd.Parameters["$is_good_quality"].Value = dataPoint.IsGoodQuality ? 1 : 0;

                    await cmd.ExecuteNonQueryAsync();
                }

                // Commit transaction
                await transaction.CommitAsync();
                transaction.Dispose();

                _totalWritten += batch.Count;
                stopwatch.Stop();

                if (_config.VerboseLogging)
                {
                    _logger.LogInformation(
                        "Wrote batch of {Count} data points in {Ms}ms. Total written: {Total}",
                        batch.Count, stopwatch.ElapsedMilliseconds, _totalWritten);
                }

                // Update tag metadata
                await UpdateTagMetadataAsync(batch);

                return; // Success
            }
            catch (SqliteException ex) when (ex.SqliteErrorCode == 5) // SQLITE_BUSY
            {
                attempt++;
                _logger.LogWarning(
                    "Database busy (attempt {Attempt}/{Max}). Retrying in {Delay}ms...",
                    attempt, _config.MaxRetryAttempts, _config.RetryDelayMs);

                if (attempt < _config.MaxRetryAttempts)
                {
                    await Task.Delay(_config.RetryDelayMs);
                }
                else
                {
                    _logger.LogError(ex, "Failed to write batch after {Attempts} attempts. Data lost.", attempt);
                    _totalDropped += batch.Count;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to write batch to database. Data lost.");
                _totalDropped += batch.Count;
                return;
            }
        }
    }

    /// <summary>
    /// Update tag metadata with latest information.
    /// Tracks first/last seen timestamps and sample counts.
    /// </summary>
    private async Task UpdateTagMetadataAsync(List<OpcUaDataValue> batch)
    {
        if (_connection == null || batch.Count == 0)
        {
            return;
        }

        try
        {
            using var cmd = _connection.CreateCommand();
            cmd.CommandText = @"
                INSERT INTO tag_metadata (node_id, display_name, data_type, first_seen, last_seen, sample_count)
                VALUES ($node_id, $display_name, $data_type, $timestamp, $timestamp, 1)
                ON CONFLICT(node_id) DO UPDATE SET
                    display_name = $display_name,
                    data_type = $data_type,
                    last_seen = $timestamp,
                    sample_count = sample_count + 1;";

            cmd.Parameters.Add("$node_id", SqliteType.Text);
            cmd.Parameters.Add("$display_name", SqliteType.Text);
            cmd.Parameters.Add("$data_type", SqliteType.Text);
            cmd.Parameters.Add("$timestamp", SqliteType.Integer);

            await cmd.PrepareAsync();

            // Update metadata for unique tags in batch
            var uniqueTags = batch.GroupBy(d => d.NodeId).Select(g => g.First());
            foreach (var dataPoint in uniqueTags)
            {
                cmd.Parameters["$node_id"].Value = dataPoint.NodeId;
                cmd.Parameters["$display_name"].Value = dataPoint.DisplayName;
                cmd.Parameters["$data_type"].Value = dataPoint.DataType;
                cmd.Parameters["$timestamp"].Value = new DateTimeOffset(dataPoint.SourceTimestamp).ToUnixTimeMilliseconds();
                
                await cmd.ExecuteNonQueryAsync();
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to update tag metadata (non-critical)");
        }
    }

    /// <summary>
    /// Periodic maintenance loop.
    /// Performs cleanup, optimization, and statistics collection.
    /// </summary>
    private async Task MaintenanceLoopAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Historian maintenance loop started.");

        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                var timeSinceLastMaintenance = DateTime.UtcNow - _lastMaintenanceTime;
                if (timeSinceLastMaintenance.TotalHours >= _config.MaintenanceIntervalHours)
                {
                    await PerformMaintenanceAsync();
                    _lastMaintenanceTime = DateTime.UtcNow;
                }

                // Wait before next check (check hourly)
                await Task.Delay(TimeSpan.FromHours(1), cancellationToken);
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in maintenance loop");
                await Task.Delay(TimeSpan.FromMinutes(10), cancellationToken);
            }
        }

        _logger.LogInformation("Historian maintenance loop stopped.");
    }

    /// <summary>
    /// Perform database maintenance operations.
    /// </summary>
    private async Task PerformMaintenanceAsync()
    {
        if (_connection == null)
        {
            return;
        }

        _logger.LogInformation("Starting database maintenance...");
        var stopwatch = Stopwatch.StartNew();

        try
        {
            // Delete old data based on retention policy
            if (_config.RetentionDays > 0)
            {
                await DeleteOldDataAsync();
            }

            // Collect statistics
            await CollectStatisticsAsync();

            // Optimize database (ANALYZE)
            using (var cmd = _connection.CreateCommand())
            {
                cmd.CommandText = "ANALYZE;";
                await cmd.ExecuteNonQueryAsync();
            }

            // VACUUM to reclaim space (only if database has grown significantly)
            var dbSize = await GetDatabaseSizeMBAsync();
            if (dbSize > 1000) // Only VACUUM if > 1GB
            {
                _logger.LogInformation("Running VACUUM to reclaim disk space...");
                using var cmd = _connection.CreateCommand();
                cmd.CommandText = "VACUUM;";
                await cmd.ExecuteNonQueryAsync();
            }

            stopwatch.Stop();
            _logger.LogInformation("Database maintenance completed in {Ms}ms", stopwatch.ElapsedMilliseconds);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during database maintenance");
        }
    }

    /// <summary>
    /// Delete data older than retention period.
    /// </summary>
    private async Task DeleteOldDataAsync()
    {
        if (_connection == null || _config.RetentionDays <= 0)
        {
            return;
        }

        try
        {
            var cutoffTimestamp = new DateTimeOffset(DateTime.UtcNow.AddDays(-_config.RetentionDays)).ToUnixTimeMilliseconds();

            using var cmd = _connection.CreateCommand();
            cmd.CommandText = "DELETE FROM data_points WHERE source_timestamp < $cutoff;";
            cmd.Parameters.AddWithValue("$cutoff", cutoffTimestamp);

            var deleted = await cmd.ExecuteNonQueryAsync();
            if (deleted > 0)
            {
                _logger.LogInformation("Deleted {Count} data points older than {Days} days", deleted, _config.RetentionDays);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to delete old data");
        }
    }

    /// <summary>
    /// Collect and store historian statistics.
    /// </summary>
    private async Task CollectStatisticsAsync()
    {
        if (_connection == null)
        {
            return;
        }

        try
        {
            var dbSize = await GetDatabaseSizeMBAsync();
            var totalPoints = await GetTotalDataPointsAsync();

            using var cmd = _connection.CreateCommand();
            cmd.CommandText = @"
                INSERT INTO historian_stats (timestamp, total_points, total_dropped, database_size_mb, queue_size)
                VALUES ($timestamp, $total_points, $total_dropped, $db_size, $queue_size);";
            
            cmd.Parameters.AddWithValue("$timestamp", DateTimeOffset.UtcNow.ToUnixTimeMilliseconds());
            cmd.Parameters.AddWithValue("$total_points", totalPoints);
            cmd.Parameters.AddWithValue("$total_dropped", _totalDropped);
            cmd.Parameters.AddWithValue("$db_size", dbSize);
            cmd.Parameters.AddWithValue("$queue_size", _dataQueue.Count);

            await cmd.ExecuteNonQueryAsync();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to collect statistics (non-critical)");
        }
    }

    /// <summary>
    /// Get database file size in megabytes.
    /// </summary>
    private async Task<double> GetDatabaseSizeMBAsync()
    {
        try
        {
            if (File.Exists(_config.DatabasePath))
            {
                return await Task.Run(() => new FileInfo(_config.DatabasePath).Length / (1024.0 * 1024.0));
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to get database size");
        }
        return 0;
    }

    /// <summary>
    /// Get total number of data points in database.
    /// </summary>
    private async Task<long> GetTotalDataPointsAsync()
    {
        if (_connection == null)
        {
            return 0;
        }

        try
        {
            using var cmd = _connection.CreateCommand();
            cmd.CommandText = "SELECT COUNT(*) FROM data_points;";
            var result = await cmd.ExecuteScalarAsync();
            return result != null ? Convert.ToInt64(result) : 0;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to get total data points");
            return 0;
        }
    }

    /// <summary>
    /// Dispose pattern implementation.
    /// </summary>
    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _logger.LogInformation("Disposing historian service...");

        // Cancel background tasks
        _writerCts?.Cancel();
        _writerCts?.Dispose();

        // Close connection
        if (_connection != null)
        {
            try
            {
                _connection.Close();
                _connection.Dispose();
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Error closing database connection");
            }
        }

        _disposed = true;
        _logger.LogInformation("Historian service disposed.");
    }
}
