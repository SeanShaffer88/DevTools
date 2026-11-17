// Bounded child-process runner for lib/DevToolsCommon.psm1.
// - No shell: arguments go through ProcessStartInfo.ArgumentList.
// - Stdin is closed immediately so children cannot block waiting for input.
// - Stdout/stderr are drained concurrently (no pipe deadlock) and capped in memory.
// - The child is placed in a kill-on-close Job Object so descendants that outlive
//   the root (and keep pipes open) are terminated instead of leaking.
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using Microsoft.Win32.SafeHandles;

namespace LocalDevTools.Common {
    public sealed class BoundedProcessResult {
        public int ExitCode;
        public bool TimedOut;
        public bool StdoutTruncated;
        public bool StderrTruncated;
        public bool JobAssigned;
        public bool DescendantsTerminated;
        public long ElapsedMilliseconds;
        public byte[] Stdout = new byte[0];
        public byte[] Stderr = new byte[0];
    }

    internal sealed class SafeJobHandle : SafeHandleZeroOrMinusOneIsInvalid {
        public SafeJobHandle() : base(true) { }
        protected override bool ReleaseHandle() { return NativeJob.CloseHandle(handle); }
    }

    internal static class NativeJob {
        internal const int JobObjectExtendedLimitInformation = 9;
        internal const uint KillOnJobClose = 0x2000;
        internal const uint ProcessMemoryLimit = 0x100;

        [StructLayout(LayoutKind.Sequential)]
        internal struct BasicLimit {
            public long PerProcessUserTimeLimit; public long PerJobUserTimeLimit; public uint LimitFlags;
            public UIntPtr MinimumWorkingSetSize; public UIntPtr MaximumWorkingSetSize; public uint ActiveProcessLimit;
            public UIntPtr Affinity; public uint PriorityClass; public uint SchedulingClass;
        }
        [StructLayout(LayoutKind.Sequential)]
        internal struct IoCounters { public ulong R, W, O, RB, WB, OB; }
        [StructLayout(LayoutKind.Sequential)]
        internal struct ExtendedLimit {
            public BasicLimit Basic; public IoCounters Io; public UIntPtr ProcessMemoryLimit;
            public UIntPtr JobMemoryLimit; public UIntPtr PeakProcessMemoryUsed; public UIntPtr PeakJobMemoryUsed;
        }

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        internal static extern SafeJobHandle CreateJobObjectW(IntPtr attributes, string name);
        [DllImport("kernel32.dll", SetLastError = true)]
        internal static extern bool SetInformationJobObject(SafeJobHandle job, int infoClass, ref ExtendedLimit info, int length);
        [DllImport("kernel32.dll", SetLastError = true)]
        internal static extern bool AssignProcessToJobObject(SafeJobHandle job, IntPtr process);
        [DllImport("kernel32.dll", SetLastError = true)]
        internal static extern bool TerminateJobObject(SafeJobHandle job, uint exitCode);
        [DllImport("kernel32.dll", SetLastError = true)]
        internal static extern bool CloseHandle(IntPtr handle);
    }

    public static class BoundedProcess {
        private const int GraceMilliseconds = 5000;
        private static readonly string[] MinimalEnvironment = {
            "SystemRoot", "windir", "SystemDrive", "TEMP", "TMP", "PATH", "PATHEXT",
            "NUMBER_OF_PROCESSORS", "PROCESSOR_ARCHITECTURE", "OS"
        };

        private sealed class Capture { public byte[] Data; public bool Truncated; }

        // Reads to EOF so the child never blocks on a full pipe, but keeps at most `limit` bytes.
        private static async Task<Capture> Drain(Stream input, int limit) {
            using (var kept = new MemoryStream()) {
                var buffer = new byte[16384];
                bool truncated = false;
                int read;
                while ((read = await input.ReadAsync(buffer, 0, buffer.Length).ConfigureAwait(false)) > 0) {
                    int room = limit - (int)kept.Length;
                    int take = Math.Min(read, Math.Max(0, room));
                    if (take > 0) kept.Write(buffer, 0, take);
                    if (take < read) truncated = true;
                }
                return new Capture { Data = kept.ToArray(), Truncated = truncated };
            }
        }

        private static SafeJobHandle CreateJob(long memoryLimitBytes) {
            var job = NativeJob.CreateJobObjectW(IntPtr.Zero, null);
            if (job.IsInvalid) { job.Dispose(); return null; }
            var info = new NativeJob.ExtendedLimit();
            info.Basic.LimitFlags = NativeJob.KillOnJobClose;
            if (memoryLimitBytes > 0) {
                info.Basic.LimitFlags |= NativeJob.ProcessMemoryLimit;
                info.ProcessMemoryLimit = new UIntPtr((ulong)memoryLimitBytes);
            }
            if (!NativeJob.SetInformationJobObject(job, NativeJob.JobObjectExtendedLimitInformation, ref info, Marshal.SizeOf(typeof(NativeJob.ExtendedLimit)))) {
                job.Dispose(); return null;
            }
            return job;
        }

        private static void Terminate(Process process, SafeJobHandle job, bool assigned) {
            if (assigned && job != null && !job.IsClosed) { NativeJob.TerminateJobObject(job, 124); }
            try { if (!process.HasExited) process.Kill(true); }
            catch (InvalidOperationException) { }
            catch (Win32Exception) { }
        }

        public static BoundedProcessResult Run(string executable, string[] arguments, string workingDirectory,
                                               int timeoutSeconds, int outputLimitBytes,
                                               IDictionary<string, string> environment, bool cleanEnvironment,
                                               long memoryLimitBytes) {
            if (string.IsNullOrEmpty(executable) || !Path.IsPathRooted(executable)) throw new ArgumentException("Executable must be an absolute path.");
            if (timeoutSeconds < 1 || timeoutSeconds > 86400) throw new ArgumentOutOfRangeException("timeoutSeconds");
            if (outputLimitBytes < 0 || outputLimitBytes > 268435456) throw new ArgumentOutOfRangeException("outputLimitBytes");
            if (memoryLimitBytes < 0) throw new ArgumentOutOfRangeException("memoryLimitBytes");

            var info = new ProcessStartInfo(executable) {
                WorkingDirectory = workingDirectory, UseShellExecute = false, CreateNoWindow = true,
                RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true
            };
            foreach (var argument in arguments ?? new string[0]) info.ArgumentList.Add(argument);
            if (cleanEnvironment) {
                var kept = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                foreach (var name in MinimalEnvironment) {
                    var value = Environment.GetEnvironmentVariable(name);
                    if (value != null) kept[name] = value;
                }
                info.Environment.Clear();
                foreach (var pair in kept) info.Environment[pair.Key] = pair.Value;
            }
            if (environment != null) foreach (var pair in environment) info.Environment[pair.Key] = pair.Value;

            var clock = Stopwatch.StartNew();
            using (var job = CreateJob(memoryLimitBytes))
            using (var process = new Process { StartInfo = info }) {
                if (!process.Start()) throw new IOException("Process did not start.");
                bool assigned = false;
                try {
                    // A descendant spawned before this call can escape the job; Kill(true) is the fallback.
                    assigned = job != null && NativeJob.AssignProcessToJobObject(job, process.Handle);
                    try { process.StandardInput.Close(); } catch (IOException) { }
                    var stdout = Drain(process.StandardOutput.BaseStream, outputLimitBytes);
                    var stderr = Drain(process.StandardError.BaseStream, outputLimitBytes);
                    var pipes = new Task[] { stdout, stderr };

                    bool timedOut = !process.WaitForExit(checked(timeoutSeconds * 1000));
                    if (timedOut) Terminate(process, job, assigned);
                    if (!process.WaitForExit(GraceMilliseconds)) throw new IOException("Process did not terminate.");

                    bool descendants = false;
                    if (!Task.WaitAll(pipes, GraceMilliseconds)) {
                        // Root exited but a descendant still holds a pipe handle.
                        descendants = true;
                        Terminate(process, job, assigned);
                        // Still open: a descendant escaped the job (e.g. children of Store/MSIX-packaged
                        // apps break away by OS policy). Disposing the Process closes our pipe ends.
                        if (!Task.WaitAll(pipes, GraceMilliseconds)) throw new IOException("Output pipes stayed open after terminating the job; a descendant outside the job (for example one started by a Store/MSIX-packaged app) still holds them.");
                    }
                    return new BoundedProcessResult {
                        ExitCode = timedOut ? 124 : process.ExitCode,
                        TimedOut = timedOut,
                        StdoutTruncated = stdout.Result.Truncated,
                        StderrTruncated = stderr.Result.Truncated,
                        JobAssigned = assigned,
                        DescendantsTerminated = descendants,
                        ElapsedMilliseconds = clock.ElapsedMilliseconds,
                        Stdout = stdout.Result.Data,
                        Stderr = stderr.Result.Data
                    };
                } catch {
                    Terminate(process, job, assigned);
                    throw;
                }
            }
        }
    }
}
