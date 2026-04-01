namespace ScadaWatcherService;

/// <summary>
/// Normalized OPC UA data value received from server.
/// Provides a consistent data model regardless of OPC UA data type.
/// Designed for easy serialization and downstream processing.
/// </summary>
public class OpcUaDataValue
{
    /// <summary>
    /// OPC UA Node Identifier that produced this value.
    /// </summary>
    public string NodeId { get; set; } = string.Empty;

    /// <summary>
    /// Friendly display name from configuration.
    /// </summary>
    public string DisplayName { get; set; } = string.Empty;

    /// <summary>
    /// Timestamp when value was sampled at the OPC UA server.
    /// Uses server timestamp for accuracy across distributed systems.
    /// </summary>
    public DateTime SourceTimestamp { get; set; }

    /// <summary>
    /// Timestamp when value was received by this client.
    /// </summary>
    public DateTime ReceivedTimestamp { get; set; }

    /// <summary>
    /// OPC UA quality status code.
    /// Good = 0x00000000 (good quality)
    /// Bad/Uncertain = other values
    /// </summary>
    public uint StatusCode { get; set; }

    /// <summary>
    /// Human-readable status description.
    /// Examples: "Good", "Bad", "Uncertain"
    /// </summary>
    public string StatusDescription { get; set; } = "Unknown";

    /// <summary>
    /// Indicates if the value quality is good.
    /// True = data is reliable
    /// False = data quality issue, treat with caution
    /// </summary>
    public bool IsGoodQuality { get; set; }

    /// <summary>
    /// Data type of the value.
    /// Examples: "Double", "Int32", "String", "Boolean", "DateTime"
    /// </summary>
    public string DataType { get; set; } = string.Empty;

    /// <summary>
    /// Value as object for type flexibility.
    /// Cast to specific type based on DataType property.
    /// Null if value is null or conversion failed.
    /// </summary>
    public object? Value { get; set; }

    /// <summary>
    /// Value converted to string for logging and display.
    /// Handles null values gracefully.
    /// </summary>
    public string ValueAsString => Value?.ToString() ?? "null";

    /// <summary>
    /// Try to get value as double (for numeric processing).
    /// </summary>
    public bool TryGetDouble(out double result)
    {
        result = 0.0;
        if (Value == null) return false;

        try
        {
            result = Convert.ToDouble(Value);
            return true;
        }
        catch
        {
            return false;
        }
    }

    /// <summary>
    /// Try to get value as integer (for discrete values).
    /// </summary>
    public bool TryGetInt32(out int result)
    {
        result = 0;
        if (Value == null) return false;

        try
        {
            result = Convert.ToInt32(Value);
            return true;
        }
        catch
        {
            return false;
        }
    }

    /// <summary>
    /// Try to get value as boolean (for digital states).
    /// </summary>
    public bool TryGetBoolean(out bool result)
    {
        result = false;
        if (Value == null) return false;

        try
        {
            result = Convert.ToBoolean(Value);
            return true;
        }
        catch
        {
            return false;
        }
    }
}
