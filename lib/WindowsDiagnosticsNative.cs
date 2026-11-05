using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Text;
[assembly: DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
namespace LocalDevTools {
 public sealed class OwnedProcess : IDisposable {
  IntPtr handle;
  public int ProcessId {get;private set;}
  public string OwnerSid {get;private set;}
  public DateTime StartUtc {get;private set;}
  public string ImagePath {get;private set;}
  [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr OpenProcess(uint access,bool inherit,int pid);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool CloseHandle(IntPtr h);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetProcessTimes(IntPtr h,out long created,out long exited,out long kernel,out long user);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetExitCodeProcess(IntPtr h,out uint code);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool QueryFullProcessImageName(IntPtr h,uint flags,StringBuilder text,ref uint size);
  [DllImport("advapi32.dll",SetLastError=true)] static extern bool OpenProcessToken(IntPtr h,uint access,out IntPtr token);
  [DllImport("advapi32.dll",SetLastError=true)] static extern bool GetTokenInformation(IntPtr token,int type,IntPtr data,int size,out int needed);
  [DllImport("dbghelp.dll",SetLastError=true)] static extern bool MiniDumpWriteDump(IntPtr h,int pid,IntPtr file,uint type,IntPtr exception,IntPtr user,IntPtr callback);
  static void Fail(string message) {throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(),message);}
  public static OwnedProcess Open(int pid) {
   var p=new OwnedProcess();p.ProcessId=pid;
   p.handle=OpenProcess(0x1000|0x400|0x10,false,pid);if(p.handle==IntPtr.Zero) Fail("Cannot open selected process.");
   try {
    long created,exited,kernel,user;if(!GetProcessTimes(p.handle,out created,out exited,out kernel,out user))Fail("Cannot identify process creation time.");p.StartUtc=DateTime.FromFileTimeUtc(created);
    IntPtr token;if(!OpenProcessToken(p.handle,8,out token))Fail("Cannot verify process owner.");
    try {int needed;GetTokenInformation(token,1,IntPtr.Zero,0,out needed);if(needed<1||needed>65536)throw new InvalidDataException("Invalid process token size.");IntPtr data=Marshal.AllocHGlobal(needed);try{if(!GetTokenInformation(token,1,data,needed,out needed))Fail("Cannot read process owner.");p.OwnerSid=new SecurityIdentifier(Marshal.ReadIntPtr(data)).Value;}finally{Marshal.FreeHGlobal(data);}}finally{CloseHandle(token);}
    if(p.OwnerSid!=WindowsIdentity.GetCurrent().User.Value)throw new UnauthorizedAccessException("Selected process is not owned by the current user.");
    var path=new StringBuilder(32768);uint size=32768;if(!QueryFullProcessImageName(p.handle,0,path,ref size))Fail("Cannot identify selected process image.");p.ImagePath=path.ToString();p.EnsureRunning();return p;
   } catch {p.Dispose();throw;}
  }
  public void EnsureRunning(){uint code;if(!GetExitCodeProcess(handle,out code))Fail("Cannot inspect process state.");if(code!=259)throw new InvalidOperationException("Selected process has exited.");}
  public void Dump(string path){EnsureRunning();using(var file=new FileStream(path,FileMode.CreateNew,FileAccess.Write,FileShare.None)){if(!MiniDumpWriteDump(handle,ProcessId,file.SafeFileHandle.DangerousGetHandle(),0,IntPtr.Zero,IntPtr.Zero,IntPtr.Zero))Fail("MiniDumpWriteDump failed.");}EnsureRunning();}
  public void Dispose(){if(handle!=IntPtr.Zero){CloseHandle(handle);handle=IntPtr.Zero;}}
 }
}
