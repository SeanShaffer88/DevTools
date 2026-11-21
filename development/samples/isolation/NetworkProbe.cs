// Original test probe. The child deliberately uses ordinary Process.Start.
using System;
using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;

class NetworkProbe {
    [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
    [DllImport("advapi32.dll",SetLastError=true)] static extern bool OpenProcessToken(IntPtr p,uint access,out IntPtr token);
    [DllImport("advapi32.dll",SetLastError=true)] static extern bool GetTokenInformation(IntPtr t,int cls,IntPtr buffer,int size,out int needed);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    static int Main(string[] args) {
        if(args.Length!=3) return 64;
        if(args[0]=="echo") {Console.WriteLine("{\"argumentBase64\":\""+Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(args[2]))+"\"}");return 0;}
        if(args[0]=="sleep") { System.Threading.Thread.Sleep(60000); return 0; }
        if(args[0]=="hang") {
            var info=new ProcessStartInfo(Process.GetCurrentProcess().MainModule.FileName,"sleep 0 unused") {UseShellExecute=false,CreateNoWindow=true};
            using(var sleeper=Process.Start(info)) {Console.WriteLine("{\"childId\":"+sleeper.Id+"}");Console.Out.Flush();System.Threading.Thread.Sleep(60000);}
            return 0;
        }
        int port=int.Parse(args[1]); IntPtr token;
        if(!OpenProcessToken(GetCurrentProcess(),8,out token)) return 65;
        bool app; int caps; int needed; IntPtr data=Marshal.AllocHGlobal(4);
        try {
            if(!GetTokenInformation(token,29,data,4,out needed)) return 66;
            app=Marshal.ReadInt32(data)!=0;
            Marshal.FreeHGlobal(data); data=IntPtr.Zero;
            GetTokenInformation(token,30,IntPtr.Zero,0,out needed); data=Marshal.AllocHGlobal(needed);
            if(!GetTokenInformation(token,30,data,needed,out needed)) return 67;
            caps=Marshal.ReadInt32(data);
        } finally { if(data!=IntPtr.Zero) Marshal.FreeHGlobal(data); CloseHandle(token); }
        int? socketError=null; bool connectTimedOut=false;
        try { using(var client=new TcpClient()) { var connect=client.ConnectAsync(IPAddress.Loopback,port); if(!connect.Wait(3000)) connectTimedOut=true; else {byte[] nonce=System.Text.Encoding.UTF8.GetBytes(args[0]+":"+args[2]); client.GetStream().Write(nonce,0,nonce.Length);socketError=0;} } }
        catch(Exception e) { var s=e as SocketException; var a=e as AggregateException; if(a!=null) s=a.GetBaseException() as SocketException; socketError=s!=null?s.NativeErrorCode:-1; }
        string child="null";
        if(args[0]=="parent") {
            var info=new ProcessStartInfo(Process.GetCurrentProcess().MainModule.FileName,"child "+port+" "+args[2]) {UseShellExecute=false,RedirectStandardOutput=true,RedirectStandardError=true,CreateNoWindow=true};
            using(var p=Process.Start(info)) { child=p.StandardOutput.ReadToEnd().Trim(); if(!p.WaitForExit(5000)) {p.Kill();return 68;} if(p.ExitCode!=0)return 69; }
        }
        Console.WriteLine("{\"isAppContainer\":"+(app?"true":"false")+",\"capabilityCount\":"+caps+",\"connectTimedOut\":"+(connectTimedOut?"true":"false")+",\"socketError\":"+(socketError.HasValue?socketError.Value.ToString():"null")+",\"child\":"+child+"}");
        return 0;
    }
}
