using Google.Cloud.Firestore;

namespace ScadaWatcherService;

/// <summary>
/// Firestore document model for alert synchronization.
/// Maps to documents in Firestore collections: alerts_active, alerts_history.
/// </summary>
[FirestoreData]
public class FirestoreAlertDocument
{
    /// <summary>
    /// Unique alert identifier (RuleId).
    /// Serves as the Firestore document ID.
    /// </summary>
    [FirestoreProperty("alertId")]
    public string AlertId { get; set; } = string.Empty;

    /// <summary>
    /// OPC UA Node ID that triggered this alert.
    /// </summary>
    [FirestoreProperty("nodeId")]
    public string NodeId { get; set; } = string.Empty;

    /// <summary>
    /// Alert rule description.
    /// </summary>
    [FirestoreProperty("description")]
    public string Description { get; set; } = string.Empty;

    /// <summary>
    /// Alert severity: "Info", "Warning", "Critical"
    /// </summary>
    [FirestoreProperty("severity")]
    public string Severity { get; set; } = string.Empty;

    /// <summary>
    /// Alert type: "HighThreshold", "LowThreshold", "RateOfChange", etc.
    /// </summary>
    [FirestoreProperty("alertType")]
    public string AlertType { get; set; } = string.Empty;

    /// <summary>
    /// Current alert state: "Inactive", "Active", "Acknowledged", "Cleared"
    /// </summary>
    [FirestoreProperty("currentState")]
    public string CurrentState { get; set; } = string.Empty;

    /// <summary>
    /// Formatted alert message.
    /// </summary>
    [FirestoreProperty("message")]
    public string Message { get; set; } = string.Empty;

    /// <summary>
    /// Value that triggered the alert (numeric, boolean, or string).
    /// Stored as object to handle multiple types.
    /// </summary>
    [FirestoreProperty("triggerValue")]
    public object? TriggerValue { get; set; }

    /// <summary>
    /// Threshold value (for threshold-based alerts).
    /// </summary>
    [FirestoreProperty("threshold")]
    public double? Threshold { get; set; }

    /// <summary>
    /// Timestamp when alert was first raised (UTC).
    /// </summary>
    [FirestoreProperty("raisedTime")]
    public Timestamp RaisedTime { get; set; }

    /// <summary>
    /// Timestamp when alert was acknowledged (UTC, nullable).
    /// </summary>
    [FirestoreProperty("acknowledgedTime")]
    public Timestamp? AcknowledgedTime { get; set; }

    /// <summary>
    /// Timestamp when alert was cleared (UTC, nullable).
    /// </summary>
    [FirestoreProperty("clearedTime")]
    public Timestamp? ClearedTime { get; set; }

    /// <summary>
    /// Timestamp of the last update to this document (UTC).
    /// </summary>
    [FirestoreProperty("lastUpdatedTime")]
    public Timestamp LastUpdatedTime { get; set; }

    /// <summary>
    /// Number of times this alert has escalated.
    /// </summary>
    [FirestoreProperty("escalationCount")]
    public int EscalationCount { get; set; } = 0;

    /// <summary>
    /// Whether this alert has been escalated.
    /// </summary>
    [FirestoreProperty("isEscalated")]
    public bool IsEscalated { get; set; } = false;

    /// <summary>
    /// User ID or device ID that acknowledged this alert (optional).
    /// </summary>
    [FirestoreProperty("acknowledgedBy")]
    public string? AcknowledgedBy { get; set; }

    /// <summary>
    /// Active duration in seconds (for cleared alerts).
    /// </summary>
    [FirestoreProperty("activeDurationSeconds")]
    public long? ActiveDurationSeconds { get; set; }

    /// <summary>
    /// Timestamp when last notification was sent (for throttling).
    /// </summary>
    [FirestoreProperty("lastNotificationTime")]
    public Timestamp? LastNotificationTime { get; set; }

    /// <summary>
    /// Count of notifications sent for this alert.
    /// </summary>
    [FirestoreProperty("notificationCount")]
    public int NotificationCount { get; set; } = 0;

    /// <summary>
    /// Creates a Firestore document from an ActiveAlert.
    /// </summary>
    public static FirestoreAlertDocument FromActiveAlert(ActiveAlert alert)
    {
        return new FirestoreAlertDocument
        {
            AlertId = alert.Rule.RuleId,
            NodeId = alert.Rule.NodeId,
            Description = alert.Rule.Description,
            Severity = alert.Rule.Severity.ToString(),
            AlertType = alert.Rule.AlertType.ToString(),
            CurrentState = alert.State.ToString(),
            Message = alert.Message,
            TriggerValue = alert.TriggerValue,
            Threshold = alert.Rule.Threshold,
            RaisedTime = Timestamp.FromDateTime(alert.FirstRaisedTime.ToUniversalTime()),
            AcknowledgedTime = alert.AcknowledgedTime.HasValue 
                ? Timestamp.FromDateTime(alert.AcknowledgedTime.Value.ToUniversalTime()) 
                : null,
            ClearedTime = alert.ClearedTime.HasValue 
                ? Timestamp.FromDateTime(alert.ClearedTime.Value.ToUniversalTime()) 
                : null,
            LastUpdatedTime = Timestamp.FromDateTime(DateTime.UtcNow),
            EscalationCount = alert.IsEscalated ? 1 : 0,
            IsEscalated = alert.IsEscalated,
            ActiveDurationSeconds = alert.ClearedTime.HasValue 
                ? (long)alert.ActiveDuration.TotalSeconds 
                : null
        };
    }
}

/// <summary>
/// Firestore document model for alert event audit trail.
/// Maps to documents in the "alert_events" collection.
/// </summary>
[FirestoreData]
public class FirestoreAlertEvent
{
    /// <summary>
    /// Event ID (auto-generated).
    /// </summary>
    [FirestoreProperty("eventId")]
    public string EventId { get; set; } = Guid.NewGuid().ToString();

    /// <summary>
    /// Alert ID (RuleId) that this event belongs to.
    /// </summary>
    [FirestoreProperty("alertId")]
    public string AlertId { get; set; } = string.Empty;

    /// <summary>
    /// Event type: "Raised", "Cleared", "Escalated", "Acknowledged"
    /// </summary>
    [FirestoreProperty("eventType")]
    public string EventType { get; set; } = string.Empty;

    /// <summary>
    /// Timestamp when the event occurred (UTC).
    /// </summary>
    [FirestoreProperty("timestamp")]
    public Timestamp Timestamp { get; set; }

    /// <summary>
    /// Alert severity at the time of the event.
    /// </summary>
    [FirestoreProperty("severity")]
    public string Severity { get; set; } = string.Empty;

    /// <summary>
    /// Event message or description.
    /// </summary>
    [FirestoreProperty("message")]
    public string Message { get; set; } = string.Empty;

    /// <summary>
    /// Value at the time of the event.
    /// </summary>
    [FirestoreProperty("value")]
    public object? Value { get; set; }

    /// <summary>
    /// User or system that triggered this event (optional).
    /// </summary>
    [FirestoreProperty("triggeredBy")]
    public string? TriggeredBy { get; set; }
}
