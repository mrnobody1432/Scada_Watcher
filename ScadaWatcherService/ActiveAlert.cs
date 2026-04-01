namespace ScadaWatcherService;

/// <summary>
/// Represents the runtime state of an active or historical alert.
/// Tracks complete lifecycle from activation through clearance.
/// Implements ISA-18.2 alarm state tracking requirements.
/// </summary>
public class ActiveAlert
{
    /// <summary>
    /// Reference to the rule that triggered this alert.
    /// </summary>
    public AlertRule Rule { get; }

    /// <summary>
    /// Current state of this alert in its lifecycle.
    /// </summary>
    public AlertState State { get; private set; }

    /// <summary>
    /// Timestamp when the alert was first raised (UTC).
    /// </summary>
    public DateTime FirstRaisedTime { get; }

    /// <summary>
    /// Timestamp when the alert was last updated (UTC).
    /// Updated on state changes and re-evaluations.
    /// </summary>
    public DateTime LastUpdatedTime { get; private set; }

    /// <summary>
    /// Timestamp when the alert was acknowledged (UTC).
    /// Null if not yet acknowledged.
    /// </summary>
    public DateTime? AcknowledgedTime { get; private set; }

    /// <summary>
    /// Timestamp when the alert condition cleared (UTC).
    /// Null if condition still active.
    /// </summary>
    public DateTime? ClearedTime { get; private set; }

    /// <summary>
    /// Timestamp when escalation occurred (UTC).
    /// Null if not escalated.
    /// </summary>
    public DateTime? EscalatedTime { get; private set; }

    /// <summary>
    /// Value that triggered the alert.
    /// Preserved for logging and display.
    /// </summary>
    public double TriggerValue { get; }

    /// <summary>
    /// Current value at last evaluation.
    /// Updated as new data arrives.
    /// </summary>
    public double CurrentValue { get; private set; }

    /// <summary>
    /// Formatted alert message with values substituted.
    /// </summary>
    public string Message { get; }

    /// <summary>
    /// Number of times this alert has been re-evaluated while active.
    /// Used for debugging chattering conditions.
    /// </summary>
    public int EvaluationCount { get; private set; }

    /// <summary>
    /// Total duration this alert has been active.
    /// </summary>
    public TimeSpan ActiveDuration => 
        (ClearedTime ?? DateTime.UtcNow) - FirstRaisedTime;

    /// <summary>
    /// Indicates if this alert has been escalated.
    /// </summary>
    public bool IsEscalated => EscalatedTime.HasValue;

    /// <summary>
    /// Indicates if escalation timer should be running.
    /// </summary>
    public bool ShouldCheckEscalation => 
        Rule.EscalationMinutes > 0 && 
        State == AlertState.Active && 
        !IsEscalated;

    public ActiveAlert(AlertRule rule, double triggerValue, string message)
    {
        Rule = rule ?? throw new ArgumentNullException(nameof(rule));
        TriggerValue = triggerValue;
        CurrentValue = triggerValue;
        Message = message;
        State = AlertState.Active;
        FirstRaisedTime = DateTime.UtcNow;
        LastUpdatedTime = DateTime.UtcNow;
        EvaluationCount = 1;
    }

    /// <summary>
    /// Updates the current value being monitored.
    /// </summary>
    public void UpdateValue(double value)
    {
        CurrentValue = value;
        LastUpdatedTime = DateTime.UtcNow;
        EvaluationCount++;
    }

    /// <summary>
    /// Marks the alert as acknowledged.
    /// </summary>
    public void Acknowledge()
    {
        if (State == AlertState.Active)
        {
            State = AlertState.Acknowledged;
            AcknowledgedTime = DateTime.UtcNow;
            LastUpdatedTime = DateTime.UtcNow;
        }
    }

    /// <summary>
    /// Marks the alert as cleared (condition returned to normal).
    /// </summary>
    public void Clear()
    {
        State = AlertState.Cleared;
        ClearedTime = DateTime.UtcNow;
        LastUpdatedTime = DateTime.UtcNow;
    }

    /// <summary>
    /// Marks the alert as escalated.
    /// </summary>
    public void Escalate()
    {
        if (!IsEscalated)
        {
            EscalatedTime = DateTime.UtcNow;
            LastUpdatedTime = DateTime.UtcNow;
        }
    }

    /// <summary>
    /// Checks if escalation should occur based on configured time.
    /// </summary>
    public bool CheckEscalationDue()
    {
        if (!ShouldCheckEscalation)
            return false;

        var minutesSinceRaised = (DateTime.UtcNow - FirstRaisedTime).TotalMinutes;
        return minutesSinceRaised >= Rule.EscalationMinutes;
    }
}
