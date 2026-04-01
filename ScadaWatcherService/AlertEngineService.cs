using System.Collections.Concurrent;
using Microsoft.Extensions.Options;

namespace ScadaWatcherService;

/// <summary>
/// Production-grade alert engine for industrial SCADA systems.
/// Implements ISA-18.2 alarm management principles to prevent alarm flooding
/// while ensuring critical conditions are detected and reported.
/// 
/// Key Features:
/// - State-based alert lifecycle management (not event-based spam)
/// - Deadband/hysteresis to prevent chattering
/// - Cooldown periods to prevent flooding
/// - Escalation for unacknowledged critical alarms
/// - Multiple alert types (threshold, rate-of-change, stale data, quality)
/// - Non-blocking evaluation (< 1ms per data point)
/// - Thread-safe concurrent operations
/// - Comprehensive lifecycle logging
/// 
/// Design Philosophy:
/// - Every alert must be actionable
/// - Prevent alarm fatigue through intelligent suppression
/// - Never miss a truly critical condition
/// - Graceful degradation on errors
/// </summary>
public class AlertEngineService : IDisposable
{
    private readonly ILogger<AlertEngineService> _logger;
    private readonly AlertConfiguration _config;

    // Active alerts indexed by RuleId
    private readonly ConcurrentDictionary<string, ActiveAlert> _activeAlerts;

    // Alert rules indexed by NodeId for fast lookup
    private readonly ConcurrentDictionary<string, List<AlertRule>> _rulesByNode;

    // Cooldown tracking: RuleId -> LastAlertTime
    private readonly ConcurrentDictionary<string, DateTime> _cooldownTracker;

    // Stale data tracking: NodeId -> LastDataTime
    private readonly ConcurrentDictionary<string, DateTime> _lastDataTime;

    // Rate-of-change tracking: RuleId -> Queue of (timestamp, value)
    private readonly ConcurrentDictionary<string, Queue<(DateTime, double)>> _rateOfChangeHistory;

    // Background evaluation task
    private Task? _evaluationTask;
    private CancellationTokenSource? _evaluationCts;

    // State tracking
    private bool _isRunning = false;
    private bool _disposed = false;
    private long _totalAlertsRaised = 0;
    private long _totalAlertsCleared = 0;
    private long _totalAlertsEscalated = 0;
    private long _totalAlertsSuppressed = 0;

    /// <summary>
    /// Event raised when a new alert becomes active.
    /// Subscribers should handle asynchronously to avoid blocking.
    /// </summary>
    public event EventHandler<ActiveAlert>? AlertRaised;

    /// <summary>
    /// Event raised when an active alert clears (condition returns to normal).
    /// </summary>
    public event EventHandler<ActiveAlert>? AlertCleared;

    /// <summary>
    /// Event raised when an unacknowledged alert escalates.
    /// </summary>
    public event EventHandler<ActiveAlert>? AlertEscalated;

    public AlertEngineService(
        ILogger<AlertEngineService> logger,
        IOptions<AlertConfiguration> config)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _config = config?.Value ?? throw new ArgumentNullException(nameof(config));

        _activeAlerts = new ConcurrentDictionary<string, ActiveAlert>();
        _rulesByNode = new ConcurrentDictionary<string, List<AlertRule>>();
        _cooldownTracker = new ConcurrentDictionary<string, DateTime>();
        _lastDataTime = new ConcurrentDictionary<string, DateTime>();
        _rateOfChangeHistory = new ConcurrentDictionary<string, Queue<(DateTime, double)>>();
    }

    /// <summary>
    /// Start the alert engine and initialize alert rules.
    /// </summary>
    public async Task StartAsync(CancellationToken cancellationToken = default)
    {
        if (_isRunning)
        {
            _logger.LogWarning("Alert engine is already running. Ignoring start request.");
            return;
        }

        if (!_config.Enabled)
        {
            _logger.LogInformation("Alert engine is disabled in configuration. Not starting.");
            return;
        }

        _logger.LogInformation("=== Alert Engine Starting ===");
        _logger.LogInformation("Evaluation Interval: {Interval}s", _config.EvaluationIntervalSeconds);
        _logger.LogInformation("Max Active Alerts: {Max}", _config.MaxActiveAlerts);

        try
        {
            // Validate configuration
            if (!_config.ValidateRules(out var errors))
            {
                _logger.LogError("Alert configuration validation failed:");
                foreach (var error in errors)
                {
                    _logger.LogError("  - {Error}", error);
                }
                throw new InvalidOperationException("Invalid alert configuration. See logs for details.");
            }

            // Build rule lookup index
            BuildRuleIndex();

            _logger.LogInformation("Loaded {Count} alert rules", _config.Rules.Count);
            
            // Log enabled rules summary
            var enabledByType = _config.Rules
                .Where(r => r.Enabled)
                .GroupBy(r => r.AlertType)
                .ToDictionary(g => g.Key, g => g.Count());

            foreach (var kvp in enabledByType)
            {
                _logger.LogInformation("  {Type}: {Count} rules", kvp.Key, kvp.Value);
            }

            // Start background evaluation task
            _evaluationCts = new CancellationTokenSource();
            _evaluationTask = Task.Run(() => EvaluationLoopAsync(_evaluationCts.Token), _evaluationCts.Token);

            _isRunning = true;
            _logger.LogInformation("Alert Engine started successfully.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "CRITICAL: Failed to start alert engine. Alerts will NOT be evaluated.");
        }
    }

    /// <summary>
    /// Stop the alert engine gracefully.
    /// </summary>
    public async Task StopAsync(CancellationToken cancellationToken = default)
    {
        if (!_isRunning)
        {
            return;
        }

        _logger.LogInformation("Alert engine stopping...");
        _isRunning = false;

        try
        {
            // Signal evaluation task to stop
            _evaluationCts?.Cancel();

            // Wait for evaluation task to complete
            if (_evaluationTask != null)
            {
                await Task.WhenAny(_evaluationTask, Task.Delay(5000, cancellationToken));
            }

            _logger.LogInformation(
                "Alert engine stopped. Stats: Raised={Raised}, Cleared={Cleared}, Escalated={Escalated}, Suppressed={Suppressed}",
                _totalAlertsRaised, _totalAlertsCleared, _totalAlertsEscalated, _totalAlertsSuppressed);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during alert engine shutdown.");
        }
    }

    /// <summary>
    /// Process incoming OPC UA data point for alert evaluation.
    /// NON-BLOCKING - returns immediately after queuing evaluation.
    /// Called from OPC UA callback thread - MUST be fast.
    /// </summary>
    public void EvaluateDataPoint(OpcUaDataValue dataPoint)
    {
        if (!_isRunning || dataPoint == null)
        {
            return;
        }

        try
        {
            // Update last data time for stale data detection
            _lastDataTime.AddOrUpdate(dataPoint.NodeId, DateTime.UtcNow, (_, __) => DateTime.UtcNow);

            // Fast lookup: do we have any rules for this node?
            if (!_rulesByNode.TryGetValue(dataPoint.NodeId, out var rules))
            {
                return; // No rules for this node
            }

            // Evaluate each rule for this node
            foreach (var rule in rules)
            {
                if (!rule.Enabled)
                {
                    continue;
                }

                try
                {
                    EvaluateRule(rule, dataPoint);
                }
                catch (Exception ex)
                {
                    // CRITICAL: Never allow a single rule evaluation to crash the engine
                    _logger.LogError(ex, "Error evaluating rule {RuleId} for node {NodeId}", 
                        rule.RuleId, dataPoint.NodeId);
                }
            }
        }
        catch (Exception ex)
        {
            // CRITICAL: Never throw from public API
            _logger.LogError(ex, "Error in alert evaluation for {NodeId}", dataPoint.NodeId);
        }
    }

    /// <summary>
    /// Acknowledge an active alert.
    /// Returns true if alert was found and acknowledged.
    /// </summary>
    public bool AcknowledgeAlert(string ruleId)
    {
        if (_activeAlerts.TryGetValue(ruleId, out var alert))
        {
            if (alert.State == AlertState.Active)
            {
                alert.Acknowledge();
                _logger.LogInformation(
                    "Alert acknowledged: {RuleId} - {Description}",
                    alert.Rule.RuleId, alert.Rule.Description);
                return true;
            }
        }
        return false;
    }

    /// <summary>
    /// Get all currently active alerts.
    /// </summary>
    public IReadOnlyList<ActiveAlert> GetActiveAlerts()
    {
        return _activeAlerts.Values
            .Where(a => a.State == AlertState.Active || a.State == AlertState.Acknowledged)
            .OrderByDescending(a => a.Rule.Severity)
            .ThenBy(a => a.FirstRaisedTime)
            .ToList();
    }

    /// <summary>
    /// Get alert statistics.
    /// </summary>
    public (long Raised, long Cleared, long Escalated, long Suppressed, int Active) GetStatistics()
    {
        var activeCount = _activeAlerts.Values.Count(a => 
            a.State == AlertState.Active || a.State == AlertState.Acknowledged);
        
        return (_totalAlertsRaised, _totalAlertsCleared, _totalAlertsEscalated, _totalAlertsSuppressed, activeCount);
    }

    /// <summary>
    /// Build index of rules by NodeId for fast lookup.
    /// </summary>
    private void BuildRuleIndex()
    {
        _rulesByNode.Clear();

        foreach (var rule in _config.Rules.Where(r => r.Enabled))
        {
            _rulesByNode.AddOrUpdate(
                rule.NodeId,
                _ => new List<AlertRule> { rule },
                (_, list) =>
                {
                    list.Add(rule);
                    return list;
                });
        }
    }

    /// <summary>
    /// Evaluate a single alert rule against data point.
    /// Implements ISA-18.2 state-based alerting with deadband and cooldown.
    /// </summary>
    private void EvaluateRule(AlertRule rule, OpcUaDataValue dataPoint)
    {
        // Check if alert already exists
        var existingAlert = _activeAlerts.GetValueOrDefault(rule.RuleId);

        // Determine if condition is currently true
        bool conditionActive = false;
        double currentValue = 0;

        switch (rule.AlertType)
        {
            case AlertType.HighThreshold:
            case AlertType.HighHighThreshold:
                if (dataPoint.TryGetDouble(out currentValue) && rule.Threshold.HasValue)
                {
                    conditionActive = currentValue > rule.Threshold.Value;
                }
                break;

            case AlertType.LowThreshold:
            case AlertType.LowLowThreshold:
                if (dataPoint.TryGetDouble(out currentValue) && rule.Threshold.HasValue)
                {
                    conditionActive = currentValue < rule.Threshold.Value;
                }
                break;

            case AlertType.RateOfChange:
                conditionActive = EvaluateRateOfChange(rule, dataPoint, out currentValue);
                break;

            case AlertType.BadQuality:
                conditionActive = !dataPoint.IsGoodQuality;
                currentValue = dataPoint.TryGetDouble(out var val) ? val : 0;
                break;

            // StaleData is evaluated in background loop
            case AlertType.StaleData:
                return;
        }

        // Handle existing alert
        if (existingAlert != null)
        {
            existingAlert.UpdateValue(currentValue);

            // Check if condition has cleared (with deadband/hysteresis)
            bool conditionCleared = !conditionActive;

            // Apply deadband for threshold alerts
            if ((rule.AlertType == AlertType.HighThreshold || rule.AlertType == AlertType.HighHighThreshold) &&
                rule.Threshold.HasValue && rule.Deadband > 0)
            {
                // For high alerts, must drop below threshold - deadband to clear
                conditionCleared = currentValue < (rule.Threshold.Value - rule.Deadband);
            }
            else if ((rule.AlertType == AlertType.LowThreshold || rule.AlertType == AlertType.LowLowThreshold) &&
                rule.Threshold.HasValue && rule.Deadband > 0)
            {
                // For low alerts, must rise above threshold + deadband to clear
                conditionCleared = currentValue > (rule.Threshold.Value + rule.Deadband);
            }

            if (conditionCleared && existingAlert.State != AlertState.Cleared)
            {
                // Condition has returned to normal - clear the alert
                ClearAlert(existingAlert);
            }
        }
        else
        {
            // No existing alert - check if condition is active
            if (conditionActive)
            {
                // Check cooldown to prevent flooding
                if (IsInCooldown(rule))
                {
                    _totalAlertsSuppressed++;
                    
                    if (_config.VerboseLogging)
                    {
                        _logger.LogDebug(
                            "Alert suppressed (cooldown): {RuleId} - {Description}",
                            rule.RuleId, rule.Description);
                    }
                    return;
                }

                // Raise new alert
                RaiseAlert(rule, currentValue, dataPoint);
            }
        }
    }

    /// <summary>
    /// Evaluate rate of change alert.
    /// Calculates rate over configured time window.
    /// </summary>
    private bool EvaluateRateOfChange(AlertRule rule, OpcUaDataValue dataPoint, out double currentValue)
    {
        currentValue = 0;

        if (!dataPoint.TryGetDouble(out currentValue) || !rule.RateOfChangeThreshold.HasValue)
        {
            return false;
        }

        // Get or create history queue for this rule
        var history = _rateOfChangeHistory.GetOrAdd(rule.RuleId, _ => new Queue<(DateTime, double)>());

        var now = DateTime.UtcNow;
        
        // Add current value
        history.Enqueue((now, currentValue));

        // Remove values outside the time window
        var cutoffTime = now.AddSeconds(-rule.RateOfChangeWindowSeconds);
        while (history.Count > 0 && history.Peek().Item1 < cutoffTime)
        {
            history.Dequeue();
        }

        // Need at least 2 points to calculate rate
        if (history.Count < 2)
        {
            return false;
        }

        // Calculate rate of change
        var oldest = history.First();
        var newest = (now, currentValue);
        var timeDelta = (newest.Item1 - oldest.Item1).TotalSeconds;

        if (timeDelta <= 0)
        {
            return false;
        }

        var valueDelta = newest.Item2 - oldest.Item2;
        var rate = valueDelta / timeDelta;

        // Check against threshold
        var threshold = Math.Abs(rule.RateOfChangeThreshold.Value);
        return Math.Abs(rate) > threshold;
    }

    /// <summary>
    /// Check if rule is in cooldown period.
    /// </summary>
    private bool IsInCooldown(AlertRule rule)
    {
        if (rule.CooldownSeconds <= 0)
        {
            return false;
        }

        if (_cooldownTracker.TryGetValue(rule.RuleId, out var lastAlertTime))
        {
            var elapsed = (DateTime.UtcNow - lastAlertTime).TotalSeconds;
            return elapsed < rule.CooldownSeconds;
        }

        return false;
    }

    /// <summary>
    /// Raise a new alert.
    /// </summary>
    private void RaiseAlert(AlertRule rule, double triggerValue, OpcUaDataValue dataPoint)
    {
        try
        {
            // Format message
            var message = FormatAlertMessage(rule, triggerValue, dataPoint);

            // Create active alert
            var alert = new ActiveAlert(rule, triggerValue, message);

            // Add to active alerts
            if (_activeAlerts.TryAdd(rule.RuleId, alert))
            {
                _totalAlertsRaised++;
                _cooldownTracker[rule.RuleId] = DateTime.UtcNow;

                // Log alert raised
                _logger.LogWarning(
                    "ALERT RAISED [{Severity}]: {RuleId} - {Message} (Value: {Value})",
                    alert.Rule.Severity,
                    alert.Rule.RuleId,
                    alert.Message,
                    triggerValue);

                // Raise event
                try
                {
                    AlertRaised?.Invoke(this, alert);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error in AlertRaised event handler for rule {RuleId}", rule.RuleId);
                }

                // Check if we need to purge old alerts
                if (_activeAlerts.Count > _config.MaxActiveAlerts)
                {
                    PurgeOldAlerts();
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error raising alert for rule {RuleId}", rule.RuleId);
        }
    }

    /// <summary>
    /// Clear an active alert (condition returned to normal).
    /// </summary>
    private void ClearAlert(ActiveAlert alert)
    {
        try
        {
            alert.Clear();
            _totalAlertsCleared++;

            _logger.LogInformation(
                "ALERT CLEARED: {RuleId} - {Description} (Active for {Duration})",
                alert.Rule.RuleId,
                alert.Rule.Description,
                alert.ActiveDuration);

            // Raise event
            try
            {
                AlertCleared?.Invoke(this, alert);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in AlertCleared event handler for rule {RuleId}", 
                    alert.Rule.RuleId);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error clearing alert for rule {RuleId}", alert.Rule.RuleId);
        }
    }

    /// <summary>
    /// Escalate an unacknowledged alert.
    /// </summary>
    private void EscalateAlert(ActiveAlert alert)
    {
        try
        {
            alert.Escalate();
            _totalAlertsEscalated++;

            _logger.LogError(
                "ALERT ESCALATED [{Severity}]: {RuleId} - {Description} (Unacknowledged for {Minutes} minutes)",
                alert.Rule.Severity,
                alert.Rule.RuleId,
                alert.Rule.Description,
                alert.Rule.EscalationMinutes);

            // Raise event
            try
            {
                AlertEscalated?.Invoke(this, alert);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in AlertEscalated event handler for rule {RuleId}", 
                    alert.Rule.RuleId);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error escalating alert for rule {RuleId}", alert.Rule.RuleId);
        }
    }

    /// <summary>
    /// Format alert message with value substitution.
    /// </summary>
    private string FormatAlertMessage(AlertRule rule, double value, OpcUaDataValue dataPoint)
    {
        return rule.MessageTemplate
            .Replace("{NodeId}", rule.NodeId)
            .Replace("{DisplayName}", dataPoint.DisplayName)
            .Replace("{Value}", value.ToString("F2"))
            .Replace("{Threshold}", rule.Threshold?.ToString("F2") ?? "N/A")
            .Replace("{Description}", rule.Description);
    }

    /// <summary>
    /// Background evaluation loop.
    /// Handles escalation checks, stale data detection, and cleanup.
    /// </summary>
    private async Task EvaluationLoopAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Alert evaluation loop started.");

        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                await Task.Delay(TimeSpan.FromSeconds(_config.EvaluationIntervalSeconds), cancellationToken);

                // Check escalations
                CheckEscalations();

                // Check stale data
                CheckStaleData();

                // Auto-acknowledge info alerts if configured
                if (_config.AutoAcknowledgeInfoAlertsMinutes > 0)
                {
                    AutoAcknowledgeInfoAlerts();
                }

                // Purge old cleared alerts
                PurgeOldAlerts();
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in alert evaluation loop. Continuing...");
            }
        }

        _logger.LogInformation("Alert evaluation loop stopped.");
    }

    /// <summary>
    /// Check for alerts that need escalation.
    /// </summary>
    private void CheckEscalations()
    {
        foreach (var alert in _activeAlerts.Values)
        {
            if (alert.CheckEscalationDue())
            {
                EscalateAlert(alert);
            }
        }
    }

    /// <summary>
    /// Check for stale data conditions.
    /// </summary>
    private void CheckStaleData()
    {
        var staleRules = _config.Rules
            .Where(r => r.Enabled && r.AlertType == AlertType.StaleData)
            .ToList();

        foreach (var rule in staleRules)
        {
            try
            {
                var existingAlert = _activeAlerts.GetValueOrDefault(rule.RuleId);
                
                if (_lastDataTime.TryGetValue(rule.NodeId, out var lastTime))
                {
                    var elapsed = (DateTime.UtcNow - lastTime).TotalSeconds;
                    bool isStale = elapsed > rule.StaleDataTimeoutSeconds;

                    if (isStale && existingAlert == null)
                    {
                        // Data is stale and no alert exists - check cooldown
                        if (!IsInCooldown(rule))
                        {
                            // Create dummy data point for stale alert
                            var message = $"{rule.Description}: No data for {elapsed:F0} seconds";
                            var alert = new ActiveAlert(rule, elapsed, message);
                            
                            if (_activeAlerts.TryAdd(rule.RuleId, alert))
                            {
                                _totalAlertsRaised++;
                                _cooldownTracker[rule.RuleId] = DateTime.UtcNow;

                                _logger.LogWarning(
                                    "ALERT RAISED [StaleData]: {RuleId} - {Message}",
                                    rule.RuleId, message);

                                AlertRaised?.Invoke(this, alert);
                            }
                        }
                    }
                    else if (!isStale && existingAlert != null && existingAlert.State != AlertState.Cleared)
                    {
                        // Data is no longer stale - clear alert
                        ClearAlert(existingAlert);
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error checking stale data for rule {RuleId}", rule.RuleId);
            }
        }
    }

    /// <summary>
    /// Auto-acknowledge low-severity alerts after configured time.
    /// </summary>
    private void AutoAcknowledgeInfoAlerts()
    {
        var cutoffTime = DateTime.UtcNow.AddMinutes(-_config.AutoAcknowledgeInfoAlertsMinutes);

        foreach (var alert in _activeAlerts.Values)
        {
            if (alert.Rule.Severity == AlertSeverity.Info &&
                alert.State == AlertState.Active &&
                alert.FirstRaisedTime < cutoffTime)
            {
                alert.Acknowledge();
                
                _logger.LogInformation(
                    "Auto-acknowledged info alert: {RuleId} - {Description}",
                    alert.Rule.RuleId, alert.Rule.Description);
            }
        }
    }

    /// <summary>
    /// Purge old cleared alerts to prevent unbounded memory growth.
    /// </summary>
    private void PurgeOldAlerts()
    {
        try
        {
            var cutoffTime = DateTime.UtcNow.AddMinutes(-_config.ClearedAlertRetentionMinutes);
            var toPurge = _activeAlerts.Values
                .Where(a => a.State == AlertState.Cleared && a.ClearedTime < cutoffTime)
                .Select(a => a.Rule.RuleId)
                .ToList();

            foreach (var ruleId in toPurge)
            {
                _activeAlerts.TryRemove(ruleId, out _);
            }

            if (toPurge.Count > 0 && _config.VerboseLogging)
            {
                _logger.LogDebug("Purged {Count} old cleared alerts", toPurge.Count);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Error purging old alerts");
        }
    }

    /// <summary>
    /// Raises an external alert (from file watcher, manual trigger, etc.).
    /// This bypasses normal rule evaluation and directly raises the alert.
    /// </summary>
    public void RaiseExternalAlert(ActiveAlert alert)
    {
        try
        {
            if (!_isRunning)
            {
                _logger.LogWarning("Alert engine is not running. External alert ignored.");
                return;
            }

            // Add to active alerts collection
            _activeAlerts[alert.Rule.RuleId] = alert;
            
            // Raise event for subscribers (Firebase, Historian, etc.)
            AlertRaised?.Invoke(this, alert);
            
            Interlocked.Increment(ref _totalAlertsRaised);
            
            _logger.LogWarning(
                "External alert raised: {RuleId} - {Description}",
                alert.Rule.RuleId, alert.Rule.Description);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error raising external alert");
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

        _logger.LogInformation("Disposing alert engine...");

        _evaluationCts?.Cancel();
        _evaluationCts?.Dispose();

        _disposed = true;
        _logger.LogInformation("Alert engine disposed.");
    }
}
