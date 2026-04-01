namespace ScadaWatcherService;

/// <summary>
/// Represents the severity level of an alert.
/// Follows ISA-18.2 classification guidelines.
/// </summary>
public enum AlertSeverity
{
    /// <summary>
    /// Informational alert - no action required, awareness only.
    /// </summary>
    Info = 0,

    /// <summary>
    /// Warning - operator awareness required, action may be needed.
    /// </summary>
    Warning = 1,

    /// <summary>
    /// Critical - immediate operator action required to prevent equipment damage or safety hazard.
    /// </summary>
    Critical = 2
}

/// <summary>
/// Represents the current state of an alert.
/// Implements ISA-18.2 alarm lifecycle state machine.
/// </summary>
public enum AlertState
{
    /// <summary>
    /// Alert condition is not present. Normal operating state.
    /// </summary>
    Inactive = 0,

    /// <summary>
    /// Alert condition detected and active, awaiting acknowledgment.
    /// </summary>
    Active = 1,

    /// <summary>
    /// Alert has been acknowledged by operator, but condition still exists.
    /// </summary>
    Acknowledged = 2,

    /// <summary>
    /// Alert condition has returned to normal and can be cleared.
    /// </summary>
    Cleared = 3
}

/// <summary>
/// Represents the type of alert condition being monitored.
/// </summary>
public enum AlertType
{
    /// <summary>
    /// Value exceeds high threshold.
    /// </summary>
    HighThreshold,

    /// <summary>
    /// Value exceeds critical high-high threshold.
    /// </summary>
    HighHighThreshold,

    /// <summary>
    /// Value falls below low threshold.
    /// </summary>
    LowThreshold,

    /// <summary>
    /// Value falls below critical low-low threshold.
    /// </summary>
    LowLowThreshold,

    /// <summary>
    /// Value is changing too rapidly (rate of change).
    /// </summary>
    RateOfChange,

    /// <summary>
    /// No data received for configured time period.
    /// </summary>
    StaleData,

    /// <summary>
    /// OPC UA data quality is bad or uncertain.
    /// </summary>
    BadQuality,

    /// <summary>
    /// Custom alert based on complex conditions.
    /// </summary>
    Custom
}

/// <summary>
/// Represents a single alert rule configuration.
/// Defines the conditions and parameters for alert detection.
/// Loaded from appsettings.json and validated on startup.
/// </summary>
public class AlertRule
{
    /// <summary>
    /// Unique identifier for this alert rule.
    /// Used for logging, acknowledgment, and state tracking.
    /// </summary>
    public string RuleId { get; set; } = string.Empty;

    /// <summary>
    /// OPC UA NodeId to monitor for this alert.
    /// Must match exactly with subscribed nodes.
    /// </summary>
    public string NodeId { get; set; } = string.Empty;

    /// <summary>
    /// Human-readable description of the alert.
    /// Presented to operators in alarm displays.
    /// </summary>
    public string Description { get; set; } = string.Empty;

    /// <summary>
    /// Type of alert condition to detect.
    /// </summary>
    public AlertType AlertType { get; set; }

    /// <summary>
    /// Severity level for this alert.
    /// Determines priority and operator response requirements.
    /// </summary>
    public AlertSeverity Severity { get; set; } = AlertSeverity.Warning;

    /// <summary>
    /// Enable or disable this alert rule.
    /// Disabled rules are not evaluated.
    /// </summary>
    public bool Enabled { get; set; } = true;

    /// <summary>
    /// Threshold value for high/low alerts.
    /// Condition triggers when value exceeds (high) or falls below (low) this value.
    /// </summary>
    public double? Threshold { get; set; }

    /// <summary>
    /// Deadband (hysteresis) value to prevent chattering.
    /// Alert must return below Threshold - Deadband before clearing.
    /// Critical for preventing alarm flooding in noisy environments.
    /// </summary>
    public double Deadband { get; set; } = 0.0;

    /// <summary>
    /// Minimum time in seconds between repeated alerts for same condition.
    /// Prevents alarm flooding from oscillating conditions.
    /// ISA-18.2 recommends minimum 30 seconds for most industrial processes.
    /// </summary>
    public int CooldownSeconds { get; set; } = 60;

    /// <summary>
    /// Time in seconds without data before triggering stale data alert.
    /// Only applies to StaleData alert type.
    /// </summary>
    public int StaleDataTimeoutSeconds { get; set; } = 300;

    /// <summary>
    /// Rate of change threshold (units per second).
    /// Only applies to RateOfChange alert type.
    /// Positive value for any rate, negative to detect decreasing only.
    /// </summary>
    public double? RateOfChangeThreshold { get; set; }

    /// <summary>
    /// Time window in seconds for rate of change calculation.
    /// Smaller windows detect rapid changes, larger windows detect sustained trends.
    /// </summary>
    public int RateOfChangeWindowSeconds { get; set; } = 60;

    /// <summary>
    /// Time in minutes before alert escalates if not acknowledged.
    /// 0 = no escalation. ISA-18.2 recommends 5-15 minutes for critical alarms.
    /// </summary>
    public int EscalationMinutes { get; set; } = 0;

    /// <summary>
    /// Custom message template for this alert.
    /// Supports placeholders: {NodeId}, {Value}, {Threshold}, {Description}
    /// </summary>
    public string MessageTemplate { get; set; } = "{Description}: Value {Value} exceeded threshold {Threshold}";

    /// <summary>
    /// Validates the alert rule configuration.
    /// Ensures all required parameters are present and valid.
    /// </summary>
    public bool IsValid(out string validationError)
    {
        validationError = string.Empty;

        if (string.IsNullOrWhiteSpace(RuleId))
        {
            validationError = "RuleId is required";
            return false;
        }

        if (string.IsNullOrWhiteSpace(NodeId))
        {
            validationError = $"NodeId is required for rule {RuleId}";
            return false;
        }

        // Threshold-based alerts require threshold value
        if ((AlertType == AlertType.HighThreshold || 
             AlertType == AlertType.HighHighThreshold ||
             AlertType == AlertType.LowThreshold || 
             AlertType == AlertType.LowLowThreshold) &&
            !Threshold.HasValue)
        {
            validationError = $"Threshold is required for {AlertType} alert in rule {RuleId}";
            return false;
        }

        // Rate of change alerts require threshold
        if (AlertType == AlertType.RateOfChange && !RateOfChangeThreshold.HasValue)
        {
            validationError = $"RateOfChangeThreshold is required for RateOfChange alert in rule {RuleId}";
            return false;
        }

        // Stale data alerts require timeout
        if (AlertType == AlertType.StaleData && StaleDataTimeoutSeconds <= 0)
        {
            validationError = $"StaleDataTimeoutSeconds must be > 0 for StaleData alert in rule {RuleId}";
            return false;
        }

        // Validate cooldown
        if (CooldownSeconds < 0)
        {
            validationError = $"CooldownSeconds cannot be negative in rule {RuleId}";
            return false;
        }

        // Validate deadband
        if (Deadband < 0)
        {
            validationError = $"Deadband cannot be negative in rule {RuleId}";
            return false;
        }

        return true;
    }
}
