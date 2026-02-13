using System;
using System.Diagnostics;
using System.ServiceProcess;
using System.Threading;
using System.Threading.Tasks;

namespace StormRaven.Kernel
{
    public class KernelService : ServiceBase
    {
        private readonly EventLog _eventLog;
        private CancellationTokenSource _cts;
        private Task _monitorTask;

        public KernelService()
        {
            ServiceName = "StormRavenKernel";
            _eventLog = new EventLog
            {
                Source = ServiceName,
                Log = "Application"
            };
        }

        protected override void OnStart(string[] args)
        {
            _cts = new CancellationTokenSource();
            var token = _cts.Token;

            _monitorTask = Task.Run(() => MonitorLoop(token), token);
        }

        protected override void OnStop()
        {
            if (_cts == null)
            {
                return;
            }

            _cts.Cancel();

            try
            {
                if (_monitorTask != null && !_monitorTask.Wait(TimeSpan.FromSeconds(5)))
                {
                    _eventLog.WriteEntry("Monitor loop did not stop within 5 seconds.", EventLogEntryType.Warning);
                }
            }
            catch (AggregateException ex)
            {
                foreach (var inner in ex.Flatten().InnerExceptions)
                {
                    _eventLog.WriteEntry($"Monitor task failed while stopping: {inner}", EventLogEntryType.Error);
                }
            }
            finally
            {
                _cts.Dispose();
                _cts = null;
                _monitorTask = null;
            }
        }

        private void MonitorLoop(CancellationToken token)
        {
            while (!token.IsCancellationRequested)
            {
                try
                {
                    RunMonitorIteration(token);
                }
                catch (OperationCanceledException) when (token.IsCancellationRequested)
                {
                    break;
                }
                catch (Exception ex)
                {
                    _eventLog.WriteEntry($"Monitor loop failure: {ex}", EventLogEntryType.Error);
                }
            }
        }

        private void RunMonitorIteration(CancellationToken token)
        {
            token.ThrowIfCancellationRequested();

            // TODO: Add monitor logic here.
            Task.Delay(TimeSpan.FromSeconds(1), token).Wait(token);
        }
    }
}
