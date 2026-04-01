using System.Text;
using System.Collections.Concurrent;
using Google.Cloud.Firestore;
using FirebaseAdmin;
using FirebaseAdmin.Messaging;

namespace ScadaWatcherService;

/// <summary>
/// Monitors alarm files in a folder and pushes alerts DIRECTLY to Firebase Cloud.
/// Reads CSV/TXT files, detects new alarms, and pushes them to Firestore in real-time.
/// Maintains SQLite database for deduplication (tracks processed alarms).
/// 
/// SIMPLIFIED ARCHITECTURE:
/// - Reads alarm files from folder
/// - Pushes directly to Firebase Firestore (no intermediate services)
/// - Sends push notifications to mobile devices
/// - Mobile app receives real-time alerts via Firestore streams
/// 
/// FILE FORMAT SUPPORT:
/// - CSV files with format: "timestamp,message" or "timestamp,severity,message"
/// - TXT files with same format
/// - Handles BOM (UTF-8-sig)
/// - Tolerates files with/without headers
/// - Allows commas in messages
/// </summary>
public class AlarmFileWatcherService : BackgroundService
{
    private readonly ILogger<AlarmFileWatcherService> _logger;
    private readonly AlarmFileWatcherConfiguration _config;
    private readonly FirebaseConfiguration _firebaseConfig;
    
    private readonly ConcurrentDictionary<string, DateTime> _processedAlarms = new();
    private FileSystemWatcher? _fileWatcher;
    private System.Data.SQLite.SQLiteConnection? _dbConnection;
    private FirestoreDb? _firestoreDb;
    private bool _firebaseInitialized = false;
    
    public AlarmFileWatcherService(
        ILogger<AlarmFileWatcherService> logger,
        AlarmFileWatcherConfiguration config,
        FirebaseConfiguration firebaseConfig)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _config = config ?? throw new ArgumentNullException(nameof(config));
        _firebaseConfig = firebaseConfig ?? throw new ArgumentNullException(nameof(firebaseConfig));
    }
    
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!_config.Enabled)
        {
            _logger.LogInformation("Alarm File Watcher is disabled in configuration");
            return;
        }
        
        try
        {
            _logger.LogInformation("Starting Alarm File Watcher Service...");
            _logger.LogInformation($"  Watch Folder: {_config.WatchFolder}");
            _logger.LogInformation($"  Database: {_config.DatabasePath}");
            _logger.LogInformation($"  Poll Interval: {_config.PollIntervalSeconds}s");
            
            // Validate configuration
            _config.Validate();
            
            // Create watch folder if it doesn't exist
            Directory.CreateDirectory(_config.WatchFolder);
            
            // Initialize SQLite database
            InitializeDatabase();
            
            // Initialize Firebase
            InitializeFirebase();
            
            // Start file system watcher (for real-time detection)
            if (_config.UseFileSystemWatcher)
            {
                StartFileSystemWatcher();
            }
            
            _logger.LogInformation("Alarm File Watcher started successfully");
            
            // Main polling loop
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    await ProcessAlarmFilesAsync(stoppingToken);
                    await Task.Delay(TimeSpan.FromSeconds(_config.PollIntervalSeconds), stoppingToken);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error in alarm file processing loop");
                    await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogCritical(ex, "CRITICAL: Alarm File Watcher failed to start");
        }
        finally
        {
            _fileWatcher?.Dispose();
            _dbConnection?.Close();
            _dbConnection?.Dispose();
        }
    }
    
    /// <summary>
    /// Initializes SQLite database for tracking processed alarms (deduplication).
    /// </summary>
    private void InitializeDatabase()
    {
        try
        {
            var dbDir = Path.GetDirectoryName(_config.DatabasePath);
            if (!string.IsNullOrEmpty(dbDir))
            {
                Directory.CreateDirectory(dbDir);
            }
            
            _dbConnection = new System.Data.SQLite.SQLiteConnection(
                $"Data Source={_config.DatabasePath};Version=3;");
            _dbConnection.Open();
            
            using var cmd = _dbConnection.CreateCommand();
            cmd.CommandText = @"
                CREATE TABLE IF NOT EXISTS alarms (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    occurred TEXT NOT NULL,
                    message TEXT NOT NULL,
                    file TEXT NOT NULL,
                    uniq TEXT UNIQUE NOT NULL,
                    processed_time TEXT NOT NULL
                )";
            cmd.ExecuteNonQuery();
            
            _logger.LogInformation("Alarm history database initialized");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to initialize alarm database");
            throw;
        }
    }
    
    /// <summary>
    /// Starts FileSystemWatcher for real-time file change detection.
    /// </summary>
    private void StartFileSystemWatcher()
    {
        try
        {
            _fileWatcher = new FileSystemWatcher(_config.WatchFolder)
            {
                NotifyFilter = NotifyFilters.LastWrite | NotifyFilters.FileName | NotifyFilters.CreationTime,
                Filter = "*.*",
                EnableRaisingEvents = true
            };
            
            _fileWatcher.Changed += async (sender, e) => await OnFileChangedAsync(e.FullPath);
            _fileWatcher.Created += async (sender, e) => await OnFileChangedAsync(e.FullPath);
            
            _logger.LogInformation("FileSystemWatcher started for real-time alarm detection");
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to start FileSystemWatcher. Will use polling only.");
        }
    }
    
    /// <summary>
    /// Handles file change events from FileSystemWatcher.
    /// </summary>
    private async Task OnFileChangedAsync(string filePath)
    {
        try
        {
            var ext = Path.GetExtension(filePath).ToLower();
            if (ext == ".csv" || ext == ".txt")
            {
                // Small delay to allow file write to complete
                await Task.Delay(100);
                await ProcessSingleFileAsync(filePath);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error processing file change event for {filePath}");
        }
    }
    
    /// <summary>
    /// Main processing loop - scans watch folder for alarm files.
    /// </summary>
    private async Task ProcessAlarmFilesAsync(CancellationToken cancellationToken)
    {
        try
        {
            var files = Directory.GetFiles(_config.WatchFolder, "*.csv")
                .Concat(Directory.GetFiles(_config.WatchFolder, "*.txt"))
                .OrderBy(f => File.GetLastWriteTime(f))
                .ToList();
            
            foreach (var file in files)
            {
                if (cancellationToken.IsCancellationRequested)
                    break;
                
                await ProcessSingleFileAsync(file);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error scanning alarm files");
        }
    }
    
    /// <summary>
    /// Processes a single alarm file.
    /// </summary>
    private async Task ProcessSingleFileAsync(string filePath)
    {
        try
        {
            var fileName = Path.GetFileName(filePath);
            var alarms = ParseAlarmFile(filePath);
            
            if (alarms.Count == 0)
                return;
            
            foreach (var (occurred, message) in alarms)
            {
                var uniq = NormalizeUniqueKey(fileName, occurred, message);
                
                if (IsAlarmProcessed(uniq))
                    continue;
                
                // Record in database
                RecordProcessedAlarm(fileName, occurred, message, uniq);
                
                // Raise alert via AlertEngineService
                await RaiseAlarmAsync(occurred, message, fileName);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error processing file {filePath}");
        }
    }
    
    /// <summary>
    /// Parses alarm file (CSV/TXT) - handles BOM, commas in messages, etc.
    /// Returns list of (timestamp, message) tuples.
    /// </summary>
    private List<(string Occurred, string Message)> ParseAlarmFile(string filePath)
    {
        var alarms = new List<(string, string)>();
        
        try
        {
            // Read with UTF-8-sig to strip BOM automatically
            var text = File.ReadAllText(filePath, Encoding.UTF8);
            
            // Remove BOM if present (fallback)
            if (text.StartsWith("\uFEFF"))
                text = text.Substring(1);
            
            var lines = text.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
            
            foreach (var line in lines)
            {
                var trimmed = line.Trim();
                if (string.IsNullOrWhiteSpace(trimmed))
                    continue;
                
                // Skip header row if present
                if (trimmed.StartsWith("Time", StringComparison.OrdinalIgnoreCase) ||
                    trimmed.StartsWith("Timestamp", StringComparison.OrdinalIgnoreCase) ||
                    trimmed.StartsWith("Occurred", StringComparison.OrdinalIgnoreCase))
                    continue;
                
                // Split on first comma only (message can contain commas)
                var commaIndex = trimmed.IndexOf(',');
                if (commaIndex > 0)
                {
                    var occurred = trimmed.Substring(0, commaIndex).Trim();
                    var message = trimmed.Substring(commaIndex + 1).Trim();
                    
                    alarms.Add((occurred, message));
                }
                else
                {
                    // No comma - treat entire line as message with current timestamp
                    var occurred = DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss");
                    alarms.Add((occurred, trimmed));
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error parsing alarm file {filePath}");
        }
        
        return alarms;
    }
    
    /// <summary>
    /// Normalizes unique key for deduplication.
    /// </summary>
    private string NormalizeUniqueKey(string fileName, string occurred, string message)
    {
        var occurredNorm = occurred.Replace("\uFEFF", "").Trim();
        var messageNorm = message.Trim();
        return $"{fileName}|{occurredNorm}|{messageNorm}";
    }
    
    /// <summary>
    /// Checks if alarm has already been processed (deduplication).
    /// </summary>
    private bool IsAlarmProcessed(string uniq)
    {
        if (_dbConnection == null)
            return false;
        
        try
        {
            using var cmd = _dbConnection.CreateCommand();
            cmd.CommandText = "SELECT COUNT(*) FROM alarms WHERE uniq = @uniq";
            cmd.Parameters.AddWithValue("@uniq", uniq);
            
            var count = Convert.ToInt32(cmd.ExecuteScalar());
            return count > 0;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Error checking alarm processed status");
            return false;
        }
    }
    
    /// <summary>
    /// Records processed alarm in database.
    /// </summary>
    private void RecordProcessedAlarm(string fileName, string occurred, string message, string uniq)
    {
        if (_dbConnection == null)
            return;
        
        try
        {
            using var cmd = _dbConnection.CreateCommand();
            cmd.CommandText = @"
                INSERT INTO alarms (occurred, message, file, uniq, processed_time)
                VALUES (@occurred, @message, @file, @uniq, @processed_time)";
            
            cmd.Parameters.AddWithValue("@occurred", occurred);
            cmd.Parameters.AddWithValue("@message", message);
            cmd.Parameters.AddWithValue("@file", fileName);
            cmd.Parameters.AddWithValue("@uniq", uniq);
            cmd.Parameters.AddWithValue("@processed_time", DateTime.UtcNow.ToString("o"));
            
            cmd.ExecuteNonQuery();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, $"Error recording processed alarm: {uniq}");
        }
    }
    
    /// <summary>
    /// Initializes Firebase connection.
    /// </summary>
    private void InitializeFirebase()
    {
        try
        {
            if (!_firebaseConfig.Enabled)
            {
                _logger.LogWarning("Firebase is disabled. Alerts will NOT be synced to cloud.");
                return;
            }
            
            _logger.LogInformation("Initializing Firebase connection...");
            
            // Validate Firebase configuration
            _firebaseConfig.Validate();
            
            // Initialize Firebase App if not already initialized
            if (FirebaseApp.DefaultInstance == null)
            {
                FirebaseApp.Create(new AppOptions()
                {
                    Credential = Google.Apis.Auth.OAuth2.GoogleCredential.FromFile(_firebaseConfig.ServiceAccountJsonPath),
                    ProjectId = _firebaseConfig.ProjectId
                });
            }
            
            // Initialize Firestore
            _firestoreDb = FirestoreDb.Create(_firebaseConfig.ProjectId);
            _firebaseInitialized = true;
            
            _logger.LogInformation("✅ Firebase initialized successfully");
            _logger.LogInformation($"   Project: {_firebaseConfig.ProjectId}");
            _logger.LogInformation($"   Collection: {_firebaseConfig.ActiveAlertsCollection}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to initialize Firebase. Alerts will NOT be synced to cloud.");
            _firebaseInitialized = false;
        }
    }
    
    /// <summary>
    /// Raises alarm and pushes DIRECTLY to Firebase Cloud.
    /// No intermediate services - direct Firestore write + push notification.
    /// </summary>
    private async Task RaiseAlarmAsync(string occurred, string message, string fileName)
    {
        try
        {
            _logger.LogInformation($"🚨 ALARM DETECTED: {message}");
            _logger.LogInformation($"   Time: {occurred}");
            _logger.LogInformation($"   File: {fileName}");
            
            // Parse timestamp
            DateTime timestamp;
            if (!DateTime.TryParse(occurred, out timestamp))
            {
                timestamp = DateTime.Now;
            }
            
            // Determine severity from message or use default
            string severity = DetermineSeverity(message);
            
            // Create alert document
            var alertId = Guid.NewGuid().ToString("N");
            var alertData = new Dictionary<string, object>
            {
                ["id"] = alertId,
                ["title"] = ExtractTitle(message),
                ["description"] = message,
                ["severity"] = severity.ToLower(),
                ["source"] = "File Watcher",
                ["location"] = fileName,
                ["equipment"] = ExtractEquipment(message),
                ["timestamp"] = Timestamp.FromDateTime(timestamp.ToUniversalTime()),
                ["status"] = "active",
                ["acknowledged"] = false,
                ["acknowledged_by"] = null,
                ["acknowledged_at"] = null,
                ["notes"] = $"Detected from file: {fileName}",
                ["created_at"] = Timestamp.FromDateTime(DateTime.UtcNow),
                ["updated_at"] = Timestamp.FromDateTime(DateTime.UtcNow)
            };
            
            // Push to Firebase Firestore
            if (_firebaseInitialized && _firestoreDb != null)
            {
                await PushToFirestoreAsync(alertId, alertData);
                await SendPushNotificationAsync(alertData);
                
                _logger.LogInformation($"✅ Alert pushed to Firebase Cloud: {alertId}");
            }
            else
            {
                _logger.LogWarning("Firebase not initialized. Alert NOT pushed to cloud.");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error raising alarm");
        }
    }
    
    /// <summary>
    /// Pushes alert to Firestore database.
    /// </summary>
    private async Task PushToFirestoreAsync(string alertId, Dictionary<string, object> alertData)
    {
        try
        {
            var collection = _firebaseConfig.ActiveAlertsCollection ?? "alerts";
            var docRef = _firestoreDb!.Collection(collection).Document(alertId);
            await docRef.SetAsync(alertData);
            
            _logger.LogInformation($"📤 Alert written to Firestore: {collection}/{alertId}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to push alert to Firestore");
        }
    }
    
    /// <summary>
    /// Sends push notification to mobile devices.
    /// </summary>
    private async Task SendPushNotificationAsync(Dictionary<string, object> alertData)
    {
        try
        {
            var severity = alertData["severity"].ToString()!;
            var title = alertData["title"].ToString()!;
            var description = alertData["description"].ToString()!;
            
            // Determine if notification should be sent based on severity
            bool shouldSend = severity switch
            {
                "critical" => _firebaseConfig.SendNotificationsForCritical,
                "warning" => _firebaseConfig.SendNotificationsForWarning,
                "info" => _firebaseConfig.SendNotificationsForInfo,
                _ => true
            };
            
            if (!shouldSend)
            {
                _logger.LogDebug($"Skipping notification for {severity} alert");
                return;
            }
            
            // Create notification message
            var message = new Message
            {
                Topic = _firebaseConfig.NotificationTopic ?? "scada_alerts",
                Notification = new Notification
                {
                    Title = $"🚨 {severity.ToUpper()}: {title}",
                    Body = description
                },
                Data = new Dictionary<string, string>
                {
                    ["alert_id"] = alertData["id"].ToString()!,
                    ["severity"] = severity,
                    ["source"] = alertData["source"].ToString()!,
                    ["timestamp"] = DateTime.UtcNow.ToString("o")
                },
                Android = new AndroidConfig
                {
                    Priority = Priority.High,
                    Notification = new AndroidNotification
                    {
                        Sound = "default",
                        ChannelId = severity == "critical" ? "critical_alerts" : "scada_alerts",
                        Priority = severity == "critical" ? NotificationPriority.MAX : NotificationPriority.HIGH
                    }
                }
            };
            
            // Send notification
            var response = await FirebaseMessaging.DefaultInstance.SendAsync(message);
            _logger.LogInformation($"📱 Push notification sent: {response}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send push notification");
        }
    }
    
    /// <summary>
    /// Determines severity from message content.
    /// </summary>
    private string DetermineSeverity(string message)
    {
        var lower = message.ToLower();
        
        if (lower.Contains("critical") || lower.Contains("emergency") || lower.Contains("danger"))
            return "Critical";
        if (lower.Contains("warning") || lower.Contains("alert") || lower.Contains("caution"))
            return "Warning";
        if (lower.Contains("info") || lower.Contains("notice"))
            return "Info";
        
        return _config.DefaultSeverity ?? "Warning";
    }
    
    /// <summary>
    /// Extracts title from message (first 50 characters or first sentence).
    /// </summary>
    private string ExtractTitle(string message)
    {
        if (string.IsNullOrEmpty(message))
            return "SCADA Alarm";
        
        var firstSentence = message.Split(new[] { '.', '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries)
            .FirstOrDefault() ?? message;
        
        return firstSentence.Length > 50 
            ? firstSentence.Substring(0, 47) + "..." 
            : firstSentence;
    }
    
    /// <summary>
    /// Extracts equipment name from message if present.
    /// </summary>
    private string ExtractEquipment(string message)
    {
        // Try to extract equipment name from common patterns
        // e.g., "PLC-01", "Tank-A", "Pump-123", etc.
        var patterns = new[]
        {
            @"([A-Z]{2,}-\d+)",  // PLC-01, HMI-02
            @"(Tank[-\s][A-Z0-9]+)", // Tank A, Tank-01
            @"(Pump[-\s][A-Z0-9]+)", // Pump 1, Pump-A
            @"(Sensor[-\s][A-Z0-9]+)" // Sensor 1
        };
        
        foreach (var pattern in patterns)
        {
            var match = System.Text.RegularExpressions.Regex.Match(message, pattern, 
                System.Text.RegularExpressions.RegexOptions.IgnoreCase);
            if (match.Success)
                return match.Groups[1].Value;
        }
        
        return "Unknown";
    }
}

/// <summary>
/// Configuration for Alarm File Watcher Service.
/// </summary>
public class AlarmFileWatcherConfiguration
{
    /// <summary>
    /// Enable or disable file-based alarm monitoring.
    /// </summary>
    public bool Enabled { get; set; } = false;
    
    /// <summary>
    /// Folder to watch for alarm files (CSV/TXT).
    /// Example: "C:\\GOT_Alarms"
    /// </summary>
    public string WatchFolder { get; set; } = @"C:\GOT_Alarms";
    
    /// <summary>
    /// SQLite database path for tracking processed alarms.
    /// Example: "C:\\AlarmSystem\\alarm_history.db"
    /// </summary>
    public string DatabasePath { get; set; } = @"C:\AlarmSystem\alarm_history.db";
    
    /// <summary>
    /// Polling interval in seconds.
    /// </summary>
    public int PollIntervalSeconds { get; set; } = 1;
    
    /// <summary>
    /// Use FileSystemWatcher for real-time detection (in addition to polling).
    /// </summary>
    public bool UseFileSystemWatcher { get; set; } = true;
    
    /// <summary>
    /// Default severity for file-based alarms.
    /// </summary>
    public AlertSeverity DefaultSeverity { get; set; } = AlertSeverity.Warning;
    
    /// <summary>
    /// Validates configuration.
    /// </summary>
    public void Validate()
    {
        if (!Enabled)
            return;
        
        if (string.IsNullOrWhiteSpace(WatchFolder))
            throw new InvalidOperationException("WatchFolder is required when AlarmFileWatcher is enabled");
        
        if (string.IsNullOrWhiteSpace(DatabasePath))
            throw new InvalidOperationException("DatabasePath is required when AlarmFileWatcher is enabled");
        
        if (PollIntervalSeconds < 1)
            throw new InvalidOperationException("PollIntervalSeconds must be >= 1");
    }
}
