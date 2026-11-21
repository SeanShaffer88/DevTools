// Original DevTools implementation. Win32 AppContainer; no network capabilities.
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Text;
using System.Threading;

public static class OfflineNative {
    [StructLayout(LayoutKind.Sequential)] struct SECURITY_CAPABILITIES { public IntPtr Sid, Capabilities; public uint Count, Reserved; }
    [StructLayout(LayoutKind.Sequential)] struct SECURITY_ATTRIBUTES { public int Length; public IntPtr Descriptor; public int Inherit; }
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct STARTUPINFO {
        public int cb; public string Reserved, Desktop, Title; public uint X,Y,XSize,YSize,XCount,YCount,Fill,Flags;
        public ushort Show, Reserved2; public IntPtr ReservedPtr, Input, Output, Error;
    }
    [StructLayout(LayoutKind.Sequential)] struct STARTUPINFOEX { public STARTUPINFO Info; public IntPtr Attributes; }
    [StructLayout(LayoutKind.Sequential)] struct PROCESS_INFORMATION { public IntPtr Process, Thread; public uint Pid, Tid; }
    [StructLayout(LayoutKind.Sequential)] struct IO_COUNTERS { public ulong A,B,C,D,E,F; }
    [StructLayout(LayoutKind.Sequential)] struct BASIC_LIMITS {
        public long PerProcess, PerJob; public uint Flags; public UIntPtr Min,Max; public uint Active;
        public UIntPtr Affinity; public uint Priority, Scheduling;
    }
    [StructLayout(LayoutKind.Sequential)] struct EXTENDED_LIMITS { public BASIC_LIMITS Basic; public IO_COUNTERS Io; public UIntPtr ProcessMemory, JobMemory, PeakProcess, PeakJob; }
    [StructLayout(LayoutKind.Sequential)] struct ACCOUNTING { public long User,Kernel,PeriodUser,PeriodKernel; public uint Faults,Total,Active,Terminated; }
    public sealed class Result { public int ExitCode; public bool TimedOut, OutputLimit; public uint ProcessId; public bool IsAppContainer; public uint CapabilityCount; public bool DescendantsTerminated; }
    [DllImport("userenv.dll", CharSet=CharSet.Unicode)] static extern int CreateAppContainerProfile(string n,string d,string desc,IntPtr c,uint count,out IntPtr sid);
    [DllImport("userenv.dll", CharSet=CharSet.Unicode)] public static extern int DeleteAppContainerProfile(string n);
    [DllImport("advapi32.dll")] static extern IntPtr FreeSid(IntPtr sid);
    [DllImport("advapi32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool ConvertStringSidToSid(string s,out IntPtr sid);
    [DllImport("kernel32.dll")] static extern IntPtr LocalFree(IntPtr p);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool InitializeProcThreadAttributeList(IntPtr p,int count,uint flags,ref IntPtr size);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool UpdateProcThreadAttribute(IntPtr p,uint flags,IntPtr attribute,IntPtr value,IntPtr size,IntPtr previous,IntPtr returned);
    [DllImport("kernel32.dll")] static extern void DeleteProcThreadAttributeList(IntPtr p);
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool CreateProcess(string app,StringBuilder cmd,IntPtr pa,IntPtr ta,bool inherit,uint flags,IntPtr env,string cwd,ref STARTUPINFOEX si,out PROCESS_INFORMATION pi);
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr CreateFile(string path,uint access,uint share,ref SECURITY_ATTRIBUTES sa,uint create,uint attributes,IntPtr template);
    [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr CreateJobObject(IntPtr a,string name);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetInformationJobObject(IntPtr job,int cls,ref EXTENDED_LIMITS info,uint len);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool QueryInformationJobObject(IntPtr job,int cls,out ACCOUNTING info,uint len,IntPtr returned);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool AssignProcessToJobObject(IntPtr job,IntPtr process);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool TerminateJobObject(IntPtr job,uint code);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool TerminateProcess(IntPtr process,uint code);
    [DllImport("kernel32.dll")] static extern uint ResumeThread(IntPtr thread);
    [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr obj,uint ms);
    [DllImport("kernel32.dll")] static extern bool GetExitCodeProcess(IntPtr process,out uint code);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    [DllImport("advapi32.dll",CharSet=CharSet.Unicode)] static extern uint GetNamedSecurityInfo(string path,int kind,uint info,out IntPtr owner,out IntPtr group,out IntPtr dacl,out IntPtr sacl,out IntPtr descriptor);
    [DllImport("advapi32.dll",SetLastError=true)] static extern bool GetAce(IntPtr acl,uint index,out IntPtr ace);
    [DllImport("advapi32.dll")] static extern bool EqualSid(IntPtr a,IntPtr b);
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern uint QueryDosDevice(string name,[Out]char[] target,uint length);
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool DefineDosDevice(uint flags,string name,string target);
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool CreateDirectory(string path,IntPtr security);
    [DllImport("advapi32.dll",SetLastError=true)] static extern bool OpenProcessToken(IntPtr process,uint access,out IntPtr token);
    [DllImport("advapi32.dll",SetLastError=true)] static extern bool GetTokenInformation(IntPtr token,int cls,IntPtr data,int size,out int needed);
    static void Check(bool ok,string op) { if(!ok) {int code=Marshal.GetLastWin32Error();throw new Win32Exception(code,op+": "+new Win32Exception(code).Message+" ("+code+")");} }
    public static string CreateProfile(string name) {
        IntPtr sid; int hr=CreateAppContainerProfile(name,name,"Disposable DevTools offline build",IntPtr.Zero,0,out sid);
        if(hr!=0) Marshal.ThrowExceptionForHR(hr);
        try { return new SecurityIdentifier(sid).Value; } finally { FreeSid(sid); }
    }
    public static void CreateDirectoryExclusive(string path) {Check(CreateDirectory(path,IntPtr.Zero),"Create unique owned profile-shadow directory");}
    public static string[] DriveTargets(string name) {
        var buffer=new char[65536];uint n=QueryDosDevice(name,buffer,(uint)buffer.Length);
        if(n==0) {int error=Marshal.GetLastWin32Error();if(error==2||error==3)return new string[0];throw new Win32Exception(error,"Query session DOS drive");}
        return new string(buffer,0,(int)n).Split(new[]{'\0'},StringSplitOptions.RemoveEmptyEntries);
    }
    public static string CreateDriveAlias(string root) {
        if(WindowsIdentity.GetCurrent().User.IsWellKnown(WellKnownSidType.LocalSystemSid))throw new InvalidOperationException("System-context global DOS mapping is forbidden");
        string target=@"\??\"+Path.GetFullPath(root);
        for(char letter='Z';letter>='D';letter--) {
            string name=letter+":";
            if(DriveTargets(name).Length!=0)continue;
            Check(DefineDosDevice(9,name,target),"Create local DOS alias");
            try {
                var after=DriveTargets(name);
                if(after.Length==1 && String.Equals(after[0],target,StringComparison.OrdinalIgnoreCase))return name;
                throw new InvalidOperationException("DOS alias changed concurrently");
            } catch(Exception original) {
                if(!DefineDosDevice(15,name,target)) {
                    int error=Marshal.GetLastWin32Error();
                    throw new AggregateException("Cannot remove newly created exact alias "+name+" -> "+target,original,new Win32Exception(error));
                }
                try {
                    if(DriveTargets(name).Length!=0)throw new InvalidOperationException("Drive still has definitions after exact failure cleanup");
                } catch(Exception cleanup) {throw new AggregateException("Post-create failure cleanup could not verify "+name+" -> "+target,original,cleanup);}
                throw new InvalidOperationException("Post-create check failed; exact alias "+name+" -> "+target+" was removed and absence verified",original);
            }
        }
        throw new InvalidOperationException("No unused session drive letter is available");
    }
    public static void RemoveDriveAlias(string name,string root) {
        string target=@"\??\"+Path.GetFullPath(root);var before=DriveTargets(name);
        bool ours=false;foreach(string value in before)if(String.Equals(value,target,StringComparison.OrdinalIgnoreCase))ours=true;
        if(!ours)throw new InvalidOperationException("Owned DOS alias is missing or changed; refusing broad removal");
        Check(DefineDosDevice(15,name,target),"Remove exact local DOS alias");
        if(DriveTargets(name).Length!=0)throw new InvalidOperationException("DOS drive still has definitions after exact cleanup");
    }
    public static string Quote(string s) {
        if(s==null || s.IndexOf('\0')>=0) throw new ArgumentException("Invalid argument");
        var b=new StringBuilder("\""); int slash=0;
        foreach(char c in s) {
            if(c=='\\') { slash++; continue; }
            if(c=='\"') { b.Append('\\',slash*2+1); b.Append(c); }
            else { b.Append('\\',slash); b.Append(c); }
            slash=0;
        }
        b.Append('\\',slash*2); b.Append('"'); return b.ToString();
    }
    public static string[] FindSidEntries(string root,string sidString) {
        IntPtr sid; Check(ConvertStringSidToSid(sidString,out sid),"Convert ACL scan SID");
        var matches=new List<string>();var pending=new Stack<string>();pending.Push(root);int count=0;
        try {
            while(pending.Count>0) {
                string path=pending.Pop();if(++count>200000)throw new InvalidOperationException("ACL scan entry limit exceeded");
                var attributes=File.GetAttributes(path);
                if((attributes&FileAttributes.ReparsePoint)!=0)throw new InvalidOperationException("Linked entry encountered during ACL scan: "+path);
                IntPtr owner,group,dacl,sacl,descriptor;
                uint status=GetNamedSecurityInfo(path,1,4,out owner,out group,out dacl,out sacl,out descriptor);
                if(status!=0)throw new Win32Exception((int)status,"Read scoped ACL");
                try {
                    if(dacl!=IntPtr.Zero) {
                        int n=(ushort)Marshal.ReadInt16(dacl,4);
                        for(uint i=0;i<n;i++) {
                            IntPtr ace;Check(GetAce(dacl,i,out ace),"Read scoped ACE");
                            // This runner creates ordinary access-allowed ACEs only.
                            if(Marshal.ReadByte(ace)==0 && EqualSid(IntPtr.Add(ace,8),sid)) {matches.Add(path);break;}
                        }
                    }
                } finally {if(descriptor!=IntPtr.Zero)LocalFree(descriptor);}
                if((attributes&FileAttributes.Directory)!=0)foreach(string child in Directory.EnumerateFileSystemEntries(path))pending.Push(child);
            }
            return matches.ToArray();
        } finally {LocalFree(sid);}
    }
    static void Token(IntPtr process,Result r) {
        IntPtr token; Check(OpenProcessToken(process,8,out token),"OpenProcessToken");
        try {
            int needed; IntPtr data=Marshal.AllocHGlobal(4);
            try { Check(GetTokenInformation(token,29,data,4,out needed),"TokenIsAppContainer"); r.IsAppContainer=Marshal.ReadInt32(data)!=0; }
            finally { Marshal.FreeHGlobal(data); }
            GetTokenInformation(token,30,IntPtr.Zero,0,out needed); data=Marshal.AllocHGlobal(needed);
            try { Check(GetTokenInformation(token,30,data,needed,out needed),"TokenCapabilities"); r.CapabilityCount=(uint)Marshal.ReadInt32(data); }
            finally { Marshal.FreeHGlobal(data); }
        } finally { CloseHandle(token); }
        if(!r.IsAppContainer || r.CapabilityCount!=0) throw new InvalidOperationException("AppContainer token invariant failed");
    }
    static void Quiesce(IntPtr job) {
        Check(TerminateJobObject(job,125),"Terminate remaining descendants");
        var wait=System.Diagnostics.Stopwatch.StartNew();
        while(true) {
            ACCOUNTING info; Check(QueryInformationJobObject(job,1,out info,(uint)Marshal.SizeOf(typeof(ACCOUNTING)),IntPtr.Zero),"Query job accounting");
            if(info.Active==0)return;
            if(wait.ElapsedMilliseconds>10000)throw new InvalidOperationException("Job still has active processes after termination");
            Thread.Sleep(20);
        }
    }
    public static Result Run(string exe,string[] args,string cwd,Dictionary<string,string> env,string sidString,int timeout,string stdout,string stderr) {
        IntPtr sid=IntPtr.Zero, list=IntPtr.Zero, cap=IntPtr.Zero, handles=IntPtr.Zero, environment=IntPtr.Zero, job=IntPtr.Zero;
        IntPtr output=IntPtr.Zero,error=IntPtr.Zero,input=IntPtr.Zero; PROCESS_INFORMATION pi=new PROCESS_INFORMATION();
        bool assigned=false, initialized=false; var result=new Result();
        try {
            Check(ConvertStringSidToSid(sidString,out sid),"ConvertStringSidToSid");
            var sa=new SECURITY_ATTRIBUTES {Length=Marshal.SizeOf(typeof(SECURITY_ATTRIBUTES)),Inherit=1};
            output=CreateFile(stdout,0x40000000,3,ref sa,1,0x80,IntPtr.Zero); Check(output!=new IntPtr(-1),"Create stdout");
            error=CreateFile(stderr,0x40000000,3,ref sa,1,0x80,IntPtr.Zero); Check(error!=new IntPtr(-1),"Create stderr");
            input=CreateFile("NUL",0x80000000,3,ref sa,3,0x80,IntPtr.Zero); Check(input!=new IntPtr(-1),"Open NUL");
            IntPtr size=IntPtr.Zero; InitializeProcThreadAttributeList(IntPtr.Zero,2,0,ref size); list=Marshal.AllocHGlobal(size);
            Check(InitializeProcThreadAttributeList(list,2,0,ref size),"Initialize attributes"); initialized=true;
            var capabilities=new SECURITY_CAPABILITIES {Sid=sid}; cap=Marshal.AllocHGlobal(Marshal.SizeOf(typeof(SECURITY_CAPABILITIES)));
            Marshal.StructureToPtr(capabilities,cap,false);
            Check(UpdateProcThreadAttribute(list,0,new IntPtr(0x20009),cap,new IntPtr(Marshal.SizeOf(typeof(SECURITY_CAPABILITIES))),IntPtr.Zero,IntPtr.Zero),"Set capabilities");
            handles=Marshal.AllocHGlobal(IntPtr.Size*3); Marshal.WriteIntPtr(handles,0,input); Marshal.WriteIntPtr(handles,IntPtr.Size,output); Marshal.WriteIntPtr(handles,IntPtr.Size*2,error);
            Check(UpdateProcThreadAttribute(list,0,new IntPtr(0x20002),handles,new IntPtr(IntPtr.Size*3),IntPtr.Zero,IntPtr.Zero),"Set handle list");
            var keys=new List<string>(env.Keys); keys.Sort(StringComparer.OrdinalIgnoreCase); var eb=new StringBuilder();
            foreach(string k in keys) { if(k.Length==0||k.IndexOf('=')>=0||k.IndexOf('\0')>=0||env[k].IndexOf('\0')>=0) throw new ArgumentException("Invalid environment"); eb.Append(k).Append('=').Append(env[k]).Append('\0'); }
            eb.Append('\0'); environment=Marshal.StringToHGlobalUni(eb.ToString());
            var si=new STARTUPINFOEX {Attributes=list}; si.Info.cb=Marshal.SizeOf(typeof(STARTUPINFOEX)); si.Info.Flags=0x100; si.Info.Input=input; si.Info.Output=output; si.Info.Error=error;
            var command=new StringBuilder(Quote(exe)); foreach(string a in args) command.Append(' ').Append(Quote(a));
            if(command.Length>32766) throw new ArgumentException("Command line too long");
            job=CreateJobObject(IntPtr.Zero,null); Check(job!=IntPtr.Zero,"Create job");
            var limits=new EXTENDED_LIMITS(); limits.Basic.Flags=0x2000;
            Check(SetInformationJobObject(job,9,ref limits,(uint)Marshal.SizeOf(typeof(EXTENDED_LIMITS))),"Set job limits");
            Check(CreateProcess(exe,command,IntPtr.Zero,IntPtr.Zero,true,0x08080404,environment,cwd,ref si,out pi),"Create AppContainer process");
            result.ProcessId=pi.Pid; Check(AssignProcessToJobObject(job,pi.Process),"Assign job"); assigned=true;
            Token(pi.Process,result); Check(ResumeThread(pi.Thread)!=0xffffffff,"Resume thread");
            var clock=System.Diagnostics.Stopwatch.StartNew();
            while(WaitForSingleObject(pi.Process,100)==258) {
                if(clock.Elapsed.TotalSeconds>timeout) { result.TimedOut=true; break; }
                if(new FileInfo(stdout).Length>64L*1024*1024 || new FileInfo(stderr).Length>64L*1024*1024) {result.OutputLimit=true; break;}
            }
            if(result.TimedOut||result.OutputLimit) Check(TerminateJobObject(job,124),"Terminate timed out job");
            WaitForSingleObject(pi.Process,5000); uint code; Check(GetExitCodeProcess(pi.Process,out code),"Get exit code"); result.ExitCode=unchecked((int)code);
            Quiesce(job); result.DescendantsTerminated=true;
            return result;
        } finally {
            try {
                if(pi.Process!=IntPtr.Zero && !assigned) TerminateProcess(pi.Process,125);
                if(job!=IntPtr.Zero) { try { if(assigned) Quiesce(job); } finally { CloseHandle(job); } }
            } finally {
                // Quiescence failure must not bypass native resource cleanup.
                if(pi.Thread!=IntPtr.Zero) CloseHandle(pi.Thread); if(pi.Process!=IntPtr.Zero) CloseHandle(pi.Process);
                foreach(IntPtr h in new[]{input,output,error}) if(h!=IntPtr.Zero && h!=new IntPtr(-1)) CloseHandle(h);
                if(initialized) DeleteProcThreadAttributeList(list);
                foreach(IntPtr p in new[]{list,cap,handles,environment}) if(p!=IntPtr.Zero) Marshal.FreeHGlobal(p);
                if(sid!=IntPtr.Zero) LocalFree(sid);
            }
        }
    }
}
