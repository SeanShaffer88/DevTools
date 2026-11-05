using System;
using System.IO;
using System.Diagnostics;
using System.Collections.Generic;
using System.Threading.Tasks;
namespace DevToolsQualityNative {
 public sealed class CommandResult {public int ExitCode;public bool TimedOut,Truncated;public byte[] Output;public string Error;}
 public static class ProcessRunner {
  sealed class Capture{public byte[] Bytes;public bool Truncated;}
  static async Task<Capture> Drain(Stream stream,int limit){using(var memory=new MemoryStream()){var buffer=new byte[8192];int n;bool truncated=false;while((n=await stream.ReadAsync(buffer,0,buffer.Length))>0){int take=Math.Min(n,Math.Max(0,limit-(int)memory.Length));memory.Write(buffer,0,take);if(take<n)truncated=true;}return new Capture{Bytes=memory.ToArray(),Truncated=truncated};}}
  public static CommandResult Run(string exe,string[] args,string cwd,int seconds,int limit,IDictionary<string,string> environment){using(var p=new Process()){p.StartInfo=new ProcessStartInfo(exe){WorkingDirectory=cwd,UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true};foreach(var a in args)p.StartInfo.ArgumentList.Add(a);if(environment!=null)foreach(var pair in environment)p.StartInfo.Environment[pair.Key]=pair.Value;if(!p.Start())throw new IOException("Process start failed");var stdout=Drain(p.StandardOutput.BaseStream,limit);var stderr=Drain(p.StandardError.BaseStream,limit);bool timeout=!p.WaitForExit(checked(seconds*1000));if(timeout){try{p.Kill(true);}catch(InvalidOperationException){}}if(!p.WaitForExit(5000)||!Task.WaitAll(new Task[]{stdout,stderr},5000))throw new IOException("Owned process or output did not terminate");return new CommandResult{ExitCode=timeout?124:p.ExitCode,TimedOut=timeout,Truncated=stdout.Result.Truncated||stderr.Result.Truncated,Output=stdout.Result.Bytes,Error=System.Text.Encoding.UTF8.GetString(stderr.Result.Bytes)};}}
 }
}
