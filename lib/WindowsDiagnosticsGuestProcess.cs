using System;
using System.IO;
using System.Text;
using System.Diagnostics;
using System.Threading.Tasks;
namespace DevToolsGuest {
 public sealed class RunResult {public int ExitCode;public bool TimedOut;public bool Truncated;public string Stdout;public string Stderr;}
 public static class ProcessRunner {
  public static string Quote(string value){var b=new StringBuilder();b.Append('"');int slashes=0;foreach(char c in value){if(c=='\\'){slashes++;continue;}if(c=='"'){b.Append('\\',slashes*2+1);b.Append(c);}else{b.Append('\\',slashes);b.Append(c);}slashes=0;}b.Append('\\',slashes*2);b.Append('"');return b.ToString();}
  static async Task<string> Drain(StreamReader r){var b=new StringBuilder();var block=new char[4096];int n;while((n=await r.ReadAsync(block,0,block.Length))>0){if(b.Length<1048576)b.Append(block,0,Math.Min(n,1048576-b.Length));}return b.ToString();}
  public static RunResult Run(string exe,string[] args,string cwd,int seconds){using(var p=new Process()){var b=new StringBuilder();foreach(string a in args){if(b.Length>0)b.Append(' ');b.Append(Quote(a));}p.StartInfo=new ProcessStartInfo(exe,b.ToString()){WorkingDirectory=cwd,UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true};if(!p.Start())throw new IOException("Guest process did not start.");var output=Drain(p.StandardOutput);var error=Drain(p.StandardError);bool timeout=!p.WaitForExit(checked(seconds*1000));if(timeout){try{p.Kill();}catch(InvalidOperationException){}}if(!p.WaitForExit(5000))throw new IOException("Guest process did not terminate.");if(!Task.WaitAll(new Task[]{output,error},5000))throw new IOException("Guest output streams did not close.");return new RunResult{ExitCode=timeout?124:p.ExitCode,TimedOut=timeout,Truncated=output.Result.Length>=1048576||error.Result.Length>=1048576,Stdout=output.Result,Stderr=error.Result};}}
 }
}
