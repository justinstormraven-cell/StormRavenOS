using System;
using System.Configuration;
using System.Diagnostics;
using System.IO;
using System.ServiceProcess;
using System.Threading;
using System.Threading.Tasks;

namespace StormRaven.Kernel
{
    public sealed class KernelService : ServiceBase
    {
        private const int DefaultPollingIntervalMs = 5000;
        private const int MinPollingIntervalMs = 1000;
        private const int StopWaitTimeoutMs = 15000;

        private CancellationTokenSource _monitorCancellation;
        private Task _monitorTask;

        public KernelService()
        {
            ServiceName = "StormRavenKernelService";
            CanStop = true;
            AutoLog = true;
        }

        protected override void OnStart(string[] args)
        {
            _monitorCancellation = new CancellationTokenSource();
            _monitorTask = Task.Run(() => MonitorLoopAsync(_monitorCancellation.Token));
        }

        protected override void OnStop()
        {
            var monitorCancellation = _monitorCancellation;
            var monitorTask = _monitorTask;

            _monitorCancellation = null;
            _monitorTask = null;

            if (monitorCancellation == null || monitorTask == null)
            {
                return;
            }

            monitorCancellation.Cancel();

            try
            {
                if (!monitorTask.Wait(StopWaitTimeoutMs))
                {
                    LogWarning($"Monitor task did not stop within {StopWaitTimeoutMs} ms.");
                }
            }
            catch (AggregateException ex)
            {
                LogException(ex.Flatten());
            }
            finally
            {
                monitorCancellation.Dispose();
            }
        }

        private async Task MonitorLoopAsync(CancellationToken cancellationToken)
        {
            var pollingInterval = GetPollingInterval();

            while (!cancellationToken.IsCancellationRequested)
            {
                try
                {
                    DoMonitorWork();
                }
                catch (Exception ex)
                {
                    LogException(ex);
                }

                try
                {
                    await Task.Delay(pollingInterval, cancellationToken).ConfigureAwait(false);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
            }
        }

        private static TimeSpan GetPollingInterval()
        {
            var setting = ConfigurationManager.AppSettings["KernelPollingIntervalMs"];
            if (int.TryParse(setting, out var configuredMs))
            {
                configuredMs = Math.Max(configuredMs, MinPollingIntervalMs);
                return TimeSpan.FromMilliseconds(configuredMs);
            }

            return TimeSpan.FromMilliseconds(DefaultPollingIntervalMs);
        }

        private void DoMonitorWork()
        {
            // Monitoring logic placeholder.
        }

        private void LogException(Exception ex)
        {
            var message = $"Unhandled exception in monitor loop: {ex}";
            LogError(message);
        }

        private void LogWarning(string message)
        {
            LogToEventLog(message, EventLogEntryType.Warning);
        }

        private void LogError(string message)
        {
            if (!LogToEventLog(message, EventLogEntryType.Error))
            {
                TryAppendFallbackLog(message);
            }
        }

        private void TryAppendFallbackLog(string message)
        {
            try
            {
                var logPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "KernelService.log");
                File.AppendAllText(logPath, $"[{DateTime.UtcNow:O}] {message}{Environment.NewLine}");
            }
            catch (Exception ex)
            {
                Trace.TraceError($"Failed to write to fallback log file: {ex}");
            }
        }

        private bool LogToEventLog(string message, EventLogEntryType entryType)
        {
            try
            {
                EventLog.WriteEntry(ServiceName, message, entryType);
                return true;
            }
            catch (Exception ex)
            {
                Trace.TraceError($"Failed to write to EventLog: {ex}");
                return false;
            }
        }
    }
}
