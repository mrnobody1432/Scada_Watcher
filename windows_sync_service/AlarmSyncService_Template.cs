using System;
using System.Data.SQLite;
using System.ServiceProcess;
using System.Timers;
using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Cloud.Firestore;
using Google.Apis.Auth.OAuth2;
using Newtonsoft.Json;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace ScadaAlarmSyncService
{
    public partial class AlarmSyncService : ServiceBase
    {
        private Timer _syncTimer;
        private FirestoreDb _firestoreDb;
        private readonly string _sqliteDbPath = @"C:\ScadaAlarms\alerts.db";
        private readonly string _serviceAccountPath = @"C:\ScadaAlarms\firebase-service-account.json";
        private readonly int _syncIntervalSeconds = 5;
        
        public AlarmSyncService()
        {
            InitializeComponent();
            ServiceName = "ScadaAlarmSyncService";
        }

        protected override void OnStart(string[] args)
        {
            try
            {
                LogMessage("Starting SCADA Alarm Sync Service...");
                InitializeFirebase();
                
                _syncTimer = new Timer(_syncIntervalSeconds * 1000);
                _syncTimer.Elapsed += OnSyncTimerElapsed;
                _syncTimer.AutoReset = true;
                _syncTimer.Start();
                
                LogMessage("Service started successfully");
            }
            catch (Exception ex)
            {
                LogError($"Error starting service: {ex.Message}");
                throw;
            }
        }

        protected override void OnStop()
        {
            LogMessage("Stopping service...");
            _syncTimer?.Stop();
            _syncTimer?.Dispose();
        }

        private void InitializeFirebase()
        {
            FirebaseApp.Create(new AppOptions
            {
                Credential = GoogleCredential.FromFile(_serviceAccountPath),
                ProjectId = "scada-alarm-system"
            });
            
            _firestoreDb = FirestoreDb.Create("scada-alarm-system");
            LogMessage("Firebase initialized");
        }

        private async void OnSyncTimerElapsed(object sender, ElapsedEventArgs e)
        {
            try
            {
                await SyncActiveAlerts();
                await SyncAlertHistory();
                await SyncSystemStatus();
                await CheckAndSendNotifications();
            }
            catch (Exception ex)
            {
                LogError($"Sync error: {ex.Message}");
            }
        }

        private async Task SyncActiveAlerts()
        {
            // Implementation here (see full version in documentation)
        }

        private async Task SyncAlertHistory()
        {
            // Implementation here
        }

        private async Task SyncSystemStatus()
        {
            // Implementation here
        }

        private async Task CheckAndSendNotifications()
        {
            // Implementation here
        }

        private void LogMessage(string message)
        {
            var logPath = @"C:\ScadaAlarms\Logs\sync_service.log";
            Directory.CreateDirectory(Path.GetDirectoryName(logPath));
            File.AppendAllText(logPath, $"{DateTime.Now:yyyy-MM-dd HH:mm:ss} [INFO] {message}\n");
        }

        private void LogError(string message)
        {
            var logPath = @"C:\ScadaAlarms\Logs\sync_service.log";
            Directory.CreateDirectory(Path.GetDirectoryName(logPath));
            File.AppendAllText(logPath, $"{DateTime.Now:yyyy-MM-dd HH:mm:ss} [ERROR] {message}\n");
        }
    }
}
