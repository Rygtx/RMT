using System;
using System.Management;

namespace RMT
{
    class Device
    {
        public static string GetDeviceId()
        {
            string id = "";
            try
            {
                using (var mc = new ManagementClass("Win32_BaseBoard"))
                    foreach (ManagementObject mo in mc.GetInstances())
                    { id += mo["SerialNumber"]?.ToString() ?? ""; break; }

                using (var mc = new ManagementClass("Win32_Processor"))
                    foreach (ManagementObject mo in mc.GetInstances())
                    { id += mo["ProcessorId"]?.ToString() ?? ""; break; }

                using (var mc = new ManagementClass("Win32_DiskDrive"))
                    foreach (ManagementObject mo in mc.GetInstances())
                    { id += mo["SerialNumber"]?.ToString() ?? ""; break; }
            }
            catch { id = Environment.MachineName + Environment.UserName; } // 回退方案

            return string.IsNullOrEmpty(id) ? "DEFAULT_" + Guid.NewGuid().ToString("N").Substring(0, 16) : id;
        }
    }
}
