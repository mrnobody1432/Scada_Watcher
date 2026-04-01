using ScadaWatcherService;
using Serilog;
using Serilog.Events;

// ============================================================================
// SCADA Watcher Service - Entry Point
// Production-grade Windows Service for managing Flutter applications
// Designed for 24/7 industrial operation with zero manual intervention
// ============================================================================

try
{
    // Load configuration to determine log path before initializing logger
    var tempConfig = new ConfigurationBuilder()
        .SetBasePath(Directory.GetCurrentDirectory())
        .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
        .AddJsonFile($"appsettings.{Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT") ?? "Production"}.json", optional: true)
        .Build();

    var loggingConfig = tempConfig.GetSection("Logging").Get<LoggingConfiguration>() 
        ?? new LoggingConfiguration();

    // Ensure log directory exists
    if (!Directory.Exists(loggingConfig.LogDirectory))
    {
        Directory.CreateDirectory(loggingConfig.LogDirectory);
    }

    // Configure Serilog for production-grade logging with rotation
    Log.Logger = new LoggerConfiguration()
        .MinimumLevel.Information()
        .MinimumLevel.Override("Microsoft", LogEventLevel.Warning)
        .MinimumLevel.Override("Microsoft.Hosting.Lifetime", LogEventLevel.Information)
        .Enrich.FromLogContext()
        .Enrich.WithMachineName()
        .Enrich.WithProcessId()
        .Enrich.WithThreadId()
        .WriteTo.Console(
            outputTemplate: "[{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz}] [{Level:u3}] {Message:lj}{NewLine}{Exception}")
        .WriteTo.File(
            path: Path.Combine(loggingConfig.LogDirectory, "ScadaWatcher-.log"),
            rollingInterval: RollingInterval.Day,
            fileSizeLimitBytes: loggingConfig.FileSizeLimitMB * 1024 * 1024,
            retainedFileCountLimit: loggingConfig.RetainedFileCount,
            rollOnFileSizeLimit: true,
            outputTemplate: "[{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz}] [{Level:u3}] [{SourceContext}] {Message:lj}{NewLine}{Exception}")
        .CreateLogger();

    Log.Information("==========================================================");
    Log.Information("SCADA Watcher Service Initializing");
    Log.Information("Environment: {Environment}", Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT") ?? "Production");
    Log.Information("Working Directory: {Directory}", Directory.GetCurrentDirectory());
    Log.Information("Log Directory: {LogDirectory}", loggingConfig.LogDirectory);
    Log.Information("==========================================================");

    // Build and configure the Windows Service host
    var builder = Host.CreateApplicationBuilder(args);

    // Add configuration sources
    builder.Configuration
        .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
        .AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", optional: true, reloadOnChange: true)
        .AddEnvironmentVariables();

    // Configure Serilog as the logging provider
    builder.Services.AddSerilog();

    // Register configuration objects for dependency injection
    builder.Services.Configure<ProcessConfiguration>(
        builder.Configuration.GetSection("ProcessManagement"));
    builder.Services.Configure<LoggingConfiguration>(
        builder.Configuration.GetSection("Logging"));

    // Register Firebase configuration (direct binding for validation)
    var firebaseConfig = builder.Configuration.GetSection("Firebase").Get<FirebaseConfiguration>() 
        ?? new FirebaseConfiguration();
    builder.Services.AddSingleton(firebaseConfig);

    // Register Alarm File Watcher configuration
    var alarmFileWatcherConfig = builder.Configuration.GetSection("AlarmFileWatcher").Get<AlarmFileWatcherConfiguration>() 
        ?? new AlarmFileWatcherConfiguration();
    builder.Services.AddSingleton(alarmFileWatcherConfig);

    // Register Alarm File Watcher service as hosted service (SIMPLIFIED - Direct Firebase push)
    builder.Services.AddHostedService<AlarmFileWatcherService>();

    // Register the worker service (for Flutter app supervision if needed)
    // builder.Services.AddHostedService<Worker>(); // DISABLED - Not needed for alarm file watching

    // CRITICAL: Enable Windows Service integration
    // This allows the application to run as a native Windows Service
    // and respond to service control manager (SCM) commands
    builder.Services.AddWindowsService(options =>
    {
        options.ServiceName = "ScadaWatcherService";
    });

    // Build and run the host
    var host = builder.Build();

    Log.Information("Host built successfully. Starting service...");
    await host.RunAsync();

    Log.Information("Service shutdown completed normally.");
}
catch (Exception ex)
{
    // CRITICAL: Log fatal startup errors before terminating
    Log.Fatal(ex, "FATAL ERROR: Service terminated due to unhandled exception during startup.");
    throw;
}
finally
{
    // Ensure all logs are flushed before exit
    Log.CloseAndFlush();
}
