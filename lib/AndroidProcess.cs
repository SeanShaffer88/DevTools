using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading.Tasks;
namespace LocalDevTools {
 public sealed class AndroidCommandResult { public int ExitCode; public bool TimedOut; public bool Truncated; public string Stdout=""; public string Stderr=""; }
 public static class AndroidProcess {
  private static async Task<string> Drain(StreamReader reader, int limit) {
   var text=new StringBuilder(); var buffer=new char[4096]; int count;
   while((count=await reader.ReadAsync(buffer,0,buffer.Length))>0) if(text.Length<limit) text.Append(buffer,0,Math.Min(count,limit-text.Length));
   return text.ToString();
  }
  public static AndroidCommandResult Run(string executable, string[] arguments, string cwd, int timeoutSeconds) {
   using(var process=new Process()) {
    process.StartInfo=new ProcessStartInfo(executable) { WorkingDirectory=cwd, UseShellExecute=false, CreateNoWindow=true, RedirectStandardOutput=true, RedirectStandardError=true };
    foreach(var argument in arguments) process.StartInfo.ArgumentList.Add(argument);
    if(!process.Start()) throw new IOException("Process did not start.");
    var output=Drain(process.StandardOutput,2097152); var error=Drain(process.StandardError,2097152);
    bool timeout=!process.WaitForExit(checked(timeoutSeconds*1000));
    if(timeout) { try { process.Kill(true); } catch(InvalidOperationException) {} }
    if(!process.WaitForExit(5000)) throw new IOException("Process did not terminate after timeout.");
    if(!Task.WaitAll(new Task[]{output,error},5000)) throw new IOException("Process output did not close.");
    var result=new AndroidCommandResult { ExitCode=timeout?124:process.ExitCode, TimedOut=timeout, Stdout=output.Result, Stderr=error.Result };
    result.Truncated=result.Stdout.Length>=2097152 || result.Stderr.Length>=2097152; return result;
   }
  }
 }
}
