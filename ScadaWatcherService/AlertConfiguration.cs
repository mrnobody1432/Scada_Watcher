namespace ScadaWatcherService;

/// <summary>
/// Configuration model for the alert engine.
/// Loaded from appsettings.json to support external configuration.
/// </summary>
public class AlertConfiguration
{
    /// <summary>
    /// Enable or disable the alert engine.
    /// Set to false to run service without alerting.
    /// </summary>
    public bool Enabled { get; set; } = true;

    /// <summary>
    /// Interval in seconds for background alert evaluation (escalation, stale data).
    /// Lower values = faster response, higher CPU usage.
    /// Recommended: 5-10 seconds for industrial applications.
    /// </summary>
    public int EvaluationIntervalSeconds { get; set; } = 5;

    /// <summary>
    /// Maximum number of active alerts to track in memory.
    /// Prevents unbounded memory growth in alarm flood scenarios.
    /// Oldest cleared alerts are purged when limit reached.
    /// Recommended: 1000-10000 depending on system size.
    /// </summary>
    public int MaxActiveAlerts { get; set; } = 5000;

    /// <summary>
    /// Time in minutes to retain cleared alerts in memory.
    /// Cleared alerts older than this are purged during maintenance.
    /// Recommended: 60-1440 (1 hour to 1 day).
    /// </summary>
    public int ClearedAlertRetentionMinutes { get; set; } = 240;

    /// <summary>
    /// Enable detailed logging of alert evaluations.
    /// WARNING: High volume in production. Use only for debugging.
    /// </summary>
    public bool VerboseLogging { get; set; } = false;

    /// <summary>
    /// Enable automatic acknowledgment of low-severity alerts after a time period.
    /// Helps reduce operator workload for non-critical alarms.
    /// 0 = disabled (operator must acknowledge all alerts).
    /// </summary>
    public int AutoAcknowledgeInfoAlertsMinutes { get; set; } = 0;

    /// <summary>
    /// Collection of alert rules to evaluate.
    /// Each rule defines a specific condition to monitor.
    /// </summary>
    public List<AlertRule> Rules { get; set; } = new();

    /// <summary>
    /// Validates all alert rules in the configuration.
    /// </summary>
    public bool ValidateRules(out List<string> errors)
    {
        errors = new List<string>();

        if (Rules == null || Rules.Count == 0)
        {
            errors.Add("No alert rules configured");
            return false;
        }

        // Check for duplicate rule IDs
        var duplicateIds = Rules
            .GroupBy(r => r.RuleId)
            .Where(g => g.Count() > 1)
            .Select(g => g.Key)
            .ToList();

        if (duplicateIds.Any())
        {
            errors.Add($"Duplicate rule IDs found: {string.Join(", ", duplicateIds)}");
        }

        // Validate each rule
        foreach (var rule in Rules)
        {
            if (!rule.IsValid(out string validationError))
            {
                errors.Add(validationError);
            }
        }

        return errors.Count == 0;
    }
}
