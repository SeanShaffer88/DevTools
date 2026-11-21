using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;
using Microsoft.Win32.SafeHandles;

internal static class NativeCancelGit
{
    private static bool Same(string left, string right)
    {
        return String.Equals(left, right, StringComparison.OrdinalIgnoreCase);
    }

    private static string Identity(Process process, string executable)
    {
        return String.Format(CultureInfo.InvariantCulture, "{0}|{1}|{2}",
            process.Id, process.StartTime.ToUniversalTime().Ticks, executable);
    }

    private static void WriteMarker(string path, string text)
    {
        string pending = path + ".pending";
        using (Stream stream = new FileStream(pending, FileMode.CreateNew))
        using (StreamWriter writer = new StreamWriter(stream))
            writer.Write(text);
        File.Move(pending, path);
    }

    private static int Main(string[] args)
    {
        string errorLog = null;
        string stage = "validate-launch";
        try
        {
            string executable = Assembly.GetExecutingAssembly().Location;
            string root = Path.GetDirectoryName(Path.GetDirectoryName(executable));
            string log = Environment.GetEnvironmentVariable("DEVTOOLS_INSPECTOR_FIXTURE_LOG");
            if (!Same(log, Path.Combine(root, "run-cancel.log"))) return 195;
            errorLog = log + ".git.error";

            if (args.Length == 3 && args[0] == "--fixture-child")
            {
                errorLog = log + ".child.error";
                stage = "validate-parent";
                using (var parent = Process.GetProcessById(Int32.Parse(args[1], CultureInfo.InvariantCulture)))
                {
                    if (!Same(parent.MainModule.FileName, executable) ||
                        parent.StartTime.ToUniversalTime().Ticks != Int64.Parse(args[2], CultureInfo.InvariantCulture))
                        return 195;
                }
                stage = "write-child-marker";
                using (var self = Process.GetCurrentProcess())
                    WriteMarker(log + ".child", Identity(self, executable));
                Thread.Sleep(35000);
                return 0;
            }

            if (args.Length != 5 || args[0] != "--no-optional-locks" || args[1] != "-C" ||
                !Same(Path.GetFullPath(args[2]), Path.Combine(root, "project")) ||
                args[3] != "rev-parse" || args[4] != "--is-inside-work-tree") return 195;

            stage = "start-child";
            using (var self = Process.GetCurrentProcess())
            {
                string childArgs = String.Format(CultureInfo.InvariantCulture, "--fixture-child {0} {1}",
                    self.Id, self.StartTime.ToUniversalTime().Ticks);
                using (var child = Process.Start(new ProcessStartInfo(executable, childArgs)
                    { UseShellExecute = false, CreateNoWindow = true }))
                {
                    stage = "write-git-marker";
                    // The observer independently validates each live executable image.
                    WriteMarker(log, Identity(self, executable) + Environment.NewLine + Identity(child, executable));
                    stage = "wait-for-child";
                    if (!child.WaitForExit(40000)) return 196;
                    if (child.ExitCode != 0) return 198;
                }
            }
            Console.WriteLine("false");
            return 0;
        }
        catch (Exception error)
        {
            string detail = String.Format(CultureInfo.InvariantCulture, "{0}: {1} (0x{2:X8})",
                stage, error.GetType().Name, error.HResult);
            if (errorLog != null)
            {
                try { WriteMarker(errorLog, detail); }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
            }
            Console.Error.WriteLine("Owned cancellation fixture failed: " + detail);
            return 197;
        }
    }
}

public static class InspectorFixtureProcessTree
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct ProcessEntry
    {
        public uint size, usage, pid;
        public UIntPtr heap;
        public uint module, threads, parent;
        public int priority;
        public uint flags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)]
        public string executable;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern SafeFileHandle CreateToolhelp32Snapshot(uint flags, uint pid);

    [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)]
    private static extern bool Process32FirstW(SafeFileHandle handle, ref ProcessEntry entry);

    [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)]
    private static extern bool Process32NextW(SafeFileHandle handle, ref ProcessEntry entry);

    public static Dictionary<int, int> Snapshot()
    {
        const uint SnapshotProcesses = 2;
        const int NoMoreFiles = 18;
        using (var handle = CreateToolhelp32Snapshot(SnapshotProcesses, 0))
        {
            if (handle.IsInvalid) throw new Win32Exception();
            var result = new Dictionary<int, int>();
            var entry = new ProcessEntry { size = (uint)Marshal.SizeOf(typeof(ProcessEntry)) };
            if (!Process32FirstW(handle, ref entry)) throw new Win32Exception();
            do
            {
                result[(int)entry.pid] = (int)entry.parent;
            } while (Process32NextW(handle, ref entry));
            if (Marshal.GetLastWin32Error() != NoMoreFiles) throw new Win32Exception();
            return result;
        }
    }
}
