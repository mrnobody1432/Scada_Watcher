using System;
using System.ServiceProcess;

namespace ScadaAlarmSyncService
{
    static class Program
    {
        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        static void Main(string[] args)
        {
            if (Environment.UserInteractive)
            {
                // Running as console application for debugging
                Console.WriteLine("SCADA Alarm Sync Service - Debug Mode");
                Console.WriteLine("======================================");
                Console.WriteLine("Press Ctrl+C to stop the service...\n");
                
                var service = new ScadaAlarmSyncService();
                service.TestStartupAndStop(args);
            }
            else
            {
                // Running as Windows Service
                ServiceBase[] ServicesToRun;
                ServicesToRun = new ServiceBase[]
                {
                    new ScadaAlarmSyncService()
                };
                ServiceBase.Run(ServicesToRun);
            }
        }
    }

    partial class ScadaAlarmSyncService
    {
        public void TestStartupAndStop(string[] args)
        {
            this.OnStart(args);
            Console.WriteLine("\nService running. Press Enter to stop...");
            Console.ReadLine();
            this.OnStop();
        }
    }
}
