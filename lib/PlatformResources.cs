using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
namespace LocalDevTools {
 public sealed class PlatformCommand { public int ExitCode; public bool TimedOut, Truncated; public byte[] Output; public string Error; }
 public static class PlatformProcess {
  private sealed class Capture { public byte[] Data; public bool Truncated; }
  private static async Task<Capture> Drain(Stream input,int limit) { using(var output=new MemoryStream()) { var buffer=new byte[8192]; int n; bool truncated=false; while((n=await input.ReadAsync(buffer,0,buffer.Length))>0) { int take=Math.Min(n,Math.Max(0,limit-(int)output.Length)); if(take>0) output.Write(buffer,0,take); if(take<n)truncated=true; } return new Capture {Data=output.ToArray(),Truncated=truncated}; } }
  public static PlatformCommand Run(string exe,string[] args,string cwd,int seconds,int limit) {
   using(var p=new Process()) {
    p.StartInfo=new ProcessStartInfo(exe) {WorkingDirectory=cwd,UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true}; foreach(var a in args)p.StartInfo.ArgumentList.Add(a);
    if(!p.Start())throw new IOException("Process did not start."); var o=Drain(p.StandardOutput.BaseStream,limit);var e=Drain(p.StandardError.BaseStream,limit);bool timeout=!p.WaitForExit(checked(seconds*1000));
    if(timeout){try{p.Kill(true);}catch(InvalidOperationException){}} if(!p.WaitForExit(5000))throw new IOException("Process did not terminate."); if(!Task.WaitAll(new Task[]{o,e},5000))throw new IOException("Output pipes did not close.");
    return new PlatformCommand {ExitCode=timeout?124:p.ExitCode,TimedOut=timeout,Truncated=o.Result.Truncated||e.Result.Truncated,Output=o.Result.Data,Error=System.Text.Encoding.UTF8.GetString(e.Result.Data)};
   }
  }
 }
}
