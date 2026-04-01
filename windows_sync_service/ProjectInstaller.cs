using System;
using System.Collections;
using System.ComponentModel;
using System.Configuration.Install;
using System.ServiceProcess;

namespace ScadaAlarmSyncService
{
    [RunInstaller(true)]
    public class ProjectInstaller : Installer
    {
        private ServiceProcessInstaller serviceProcessInstaller;
        private ServiceInstaller serviceInstaller;

        public ProjectInstaller()
        {
            serviceProcessInstaller = new ServiceProcessInstaller();
            serviceInstaller = new ServiceInstaller();

            // Service will run under the Local System account
            serviceProcessInstaller.Account = ServiceAccount.LocalSystem;
            serviceProcessInstaller.Username = null;
            serviceProcessInstaller.Password = null;

            // Service configuration
            serviceInstaller.ServiceName = "ScadaAlarmSyncService";
            serviceInstaller.DisplayName = "SCADA Alarm Cloud Sync Service";
            serviceInstaller.Description = "Synchronizes SCADA alarm data between local SQLite database and Firebase cloud backend with bidirectional push/fetch support";
            serviceInstaller.StartType = ServiceStartMode.Automatic;
            
            // Add both installers to the Installers collection
            Installers.Add(serviceProcessInstaller);
            Installers.Add(serviceInstaller);
        }
    }
}
