using System;
using System.IO;
using System.Text;
using System.Text.Json;
using System.Linq;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading.Tasks;
using System.Security.Cryptography;
namespace DevTools.QualityGames {
 public static class Data {
  public static string Canonical(string json) { using(var d=JsonDocument.Parse(json,new JsonDocumentOptions{MaxDepth=32})) {var b=new StringBuilder();Write(d.RootElement,b);return b.ToString();} }
  static void Write(JsonElement e,StringBuilder b) {
   switch(e.ValueKind) {
    case JsonValueKind.Object: b.Append('{');bool first=true;var seen=new HashSet<string>(StringComparer.Ordinal);foreach(var p in e.EnumerateObject().OrderBy(p=>p.Name,StringComparer.Ordinal)){if(!seen.Add(p.Name))throw new InvalidDataException("Duplicate JSON property.");if(!first)b.Append(',');first=false;b.Append(JsonSerializer.Serialize(p.Name)).Append(':');Write(p.Value,b);}b.Append('}');break;
    case JsonValueKind.Array:b.Append('[');bool f=true;foreach(var x in e.EnumerateArray()){if(!f)b.Append(',');f=false;Write(x,b);}b.Append(']');break;
    case JsonValueKind.String:b.Append(JsonSerializer.Serialize(e.GetString()));break;
    case JsonValueKind.Number: if(!e.TryGetDouble(out double n)||!double.IsFinite(n))throw new InvalidDataException("Nonfinite JSON number.");b.Append(e.GetRawText());break;
    default:b.Append(e.GetRawText());break;
   }
  }
  public static string Hash(string json) {return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(Canonical(json)))).ToLowerInvariant();}
 }
 public class CommandResult {public int Pid;public int ExitCode;public bool TimedOut;public bool Truncated;public string Output="";public string Error="";}
 public static class Command {
  static async Task<string> Read(StreamReader reader,int limit,Action exceeded) {var b=new StringBuilder();var buffer=new char[4096];int n;while((n=await reader.ReadAsync(buffer,0,buffer.Length))>0){if(b.Length+n>limit){exceeded();break;}b.Append(buffer,0,n);}return b.ToString();}
  public static CommandResult Run(string exe,string[] args,string input,int seconds,int limit,string directory) {
   var r=new CommandResult();var si=new ProcessStartInfo(exe){UseShellExecute=false,CreateNoWindow=true,RedirectStandardInput=true,RedirectStandardOutput=true,RedirectStandardError=true,WorkingDirectory=directory};foreach(var a in args)si.ArgumentList.Add(a);
   using(var p=new Process{StartInfo=si}){if(!p.Start())throw new IOException("Process did not start.");r.Pid=p.Id;Action stop=()=>{r.Truncated=true;try{p.Kill(true);}catch{}};var o=Read(p.StandardOutput,limit,stop);var e=Read(p.StandardError,limit,stop);var write=Task.Run(async()=>{try{await p.StandardInput.WriteAsync(input??"");p.StandardInput.Close();}catch(IOException){} });
    if(!p.WaitForExit(seconds*1000)){r.TimedOut=true;try{p.Kill(true);}catch{}}if(!p.WaitForExit(3000))throw new IOException("Selected process did not terminate.");if(!Task.WaitAll(new Task[]{o,e,write},3000))throw new IOException("Redirected streams did not close.");r.Output=o.Result;r.Error=e.Result;r.ExitCode=p.ExitCode;return r;}
  }
 }
 public class MediaInfo {public string Kind="";public long Width;public long Height;public string Alpha="Unknown";public long Channels;public long SampleRate;public long Bits;public double Duration;public string Checks="";}
 public static class Media {
  static void Need(bool v,string message){if(!v)throw new InvalidDataException(message);}
  static uint BE(byte[] b,int p){Need(p>=0&&p+4<=b.Length,"Truncated integer.");return (uint)b[p]<<24|(uint)b[p+1]<<16|(uint)b[p+2]<<8|b[p+3];}
  static uint LE(byte[] b,int p){Need(p>=0&&p+4<=b.Length,"Truncated integer.");return (uint)b[p]|(uint)b[p+1]<<8|(uint)b[p+2]<<16|(uint)b[p+3]<<24;}
  static int U16(byte[] b,int p){Need(p>=0&&p+2<=b.Length,"Truncated short.");return b[p]|b[p+1]<<8;}
  static uint Crc(byte[] b,int p,int n){uint c=0xffffffff;for(int i=p;i<p+n;i++){c^=b[i];for(int j=0;j<8;j++)c=(c&1)!=0?(c>>1)^0xedb88320:c>>1;}return c^0xffffffff;}
  static string S(byte[] b,int p,int n){Need(p>=0&&p+n<=b.Length,"Truncated signature.");return Encoding.ASCII.GetString(b,p,n);}
  public static MediaInfo Inspect(byte[] b,string ext){var m=new MediaInfo();
   if(ext==".png") {
    Need(b.Length>=45&&Convert.ToHexString(b.AsSpan(0,8))=="89504E470D0A1A0A","Invalid PNG signature/header.");int p=8;bool ih=false,id=false,end=false,palette=false;int color=0;
    while(p<b.Length){Need(p+12<=b.Length,"Truncated PNG chunk.");uint len=BE(b,p);Need(len<=int.MaxValue&&p+12L+len<=b.Length,"PNG chunk out of bounds.");int n=(int)len;string kind=S(b,p+4,4);Need(kind.All(c=>c>='A'&&c<='Z'||c>='a'&&c<='z'),"Invalid PNG chunk name.");Need(Crc(b,p+4,n+4)==BE(b,p+8+n),"PNG CRC mismatch.");
     if(!ih){Need(kind=="IHDR"&&n==13,"PNG must start with IHDR.");m.Width=BE(b,p+8);m.Height=BE(b,p+12);color=b[p+17];int depth=b[p+16];Need(m.Width>0&&m.Height>0&&m.Width<=int.MaxValue&&m.Height<=int.MaxValue,"Invalid PNG dimensions.");Need((color==0&&new[]{1,2,4,8,16}.Contains(depth))||(color==2&&new[]{8,16}.Contains(depth))||(color==3&&new[]{1,2,4,8}.Contains(depth))||((color==4||color==6)&&new[]{8,16}.Contains(depth)),"Invalid PNG color/depth.");Need(b[p+18]==0&&b[p+19]==0&&b[p+20]<=1,"Unsupported PNG methods.");m.Alpha=color==4||color==6?"Present":"Absent";ih=true;
     }else{Need(kind!="IHDR","Repeated IHDR.");if(kind=="PLTE"){Need(!id&&n>0&&n%3==0&&n<=768,"Invalid PNG palette.");palette=true;}if(kind=="tRNS"){Need(!id&&(color==0&&n==2||color==2&&n==6||color==3&&palette&&n>0&&n<=256),"Invalid PNG transparency.");m.Alpha="Present";}if(kind=="IDAT"){Need(color!=3||palette,"PNG palette missing.");id=true;}if(kind=="IEND"){Need(n==0&&id&&p+12==b.Length,"Invalid PNG ending.");end=true;}}
     p+=12+n;
    }Need(end,"PNG IEND missing.");m.Kind="PNG";m.Checks="Signature, chunk bounds/order, IHDR fields, all chunk CRCs; IDAT compressed pixels not decoded";
   }else if(ext==".bmp") {
    Need(b.Length>=54&&S(b,0,2)=="BM"&&LE(b,2)==b.Length,"Invalid BMP header/length.");uint offset=LE(b,10),dib=LE(b,14);Need(dib>=40&&14L+dib<=b.Length&&offset>=14L+dib,"Invalid BMP DIB/offset.");int w=(int)LE(b,18),h=(int)LE(b,22),bits=U16(b,28);Need(w>0&&h!=0&&h!=int.MinValue&&U16(b,26)==1,"Invalid BMP dimensions/planes.");Need(LE(b,30)==0&&new[]{24,32}.Contains(bits),"Unsupported BMP encoding; only uncompressed 24/32 bit supported.");long row=checked(((long)w*bits+31)/32*4),height=Math.Abs((long)h);Need(offset<=b.LongLength&&height<=(b.LongLength-offset)/row,"Truncated or oversized BMP pixels.");m.Kind="BMP";m.Width=w;m.Height=height;m.Alpha=bits==24?"Absent":"Unknown";m.Checks="Header, dimensions, overflow-safe uncompressed pixel storage bounds; 32-bit unused/alpha bytes ambiguous";
   }else if(ext==".jpg"||ext==".jpeg") {
    Need(b.Length>=4&&b[0]==255&&b[1]==216,"Invalid JPEG signature.");int p=2;bool frame=false,scan=false,end=false;
    while(p<b.Length){Need(b[p++]==255,"Invalid JPEG marker.");while(p<b.Length&&b[p]==255)p++;Need(p<b.Length,"Truncated JPEG marker.");int marker=b[p++];if(marker==217){end=true;Need(p==b.Length,"Trailing JPEG bytes.");break;}Need(marker!=216&&marker!=0,"Invalid JPEG marker sequence.");if(marker>=208&&marker<=215)continue;Need(p+2<=b.Length,"Truncated JPEG segment.");int len=b[p]*256+b[p+1];Need(len>=2&&p+len<=b.Length,"JPEG segment bounds.");
     if(new[]{192,193,194}.Contains(marker)){Need(len>=8,"JPEG SOF truncated.");m.Height=b[p+3]*256+b[p+4];m.Width=b[p+5]*256+b[p+6];Need(m.Width>0&&m.Height>0&&len==8+3*b[p+7],"Invalid JPEG frame.");frame=true;}
     if(marker==218){Need(frame&&len>=6,"Invalid JPEG scan.");scan=true;p+=len;while(p<b.Length){if(b[p]!=255){p++;continue;}int s=p;while(p<b.Length&&b[p]==255)p++;Need(p<b.Length,"Truncated JPEG entropy marker.");if(b[p]==0||b[p]>=208&&b[p]<=215){p++;continue;}p=s;break;}continue;}p+=len;
    }Need(end&&frame&&scan,"Incomplete JPEG.");m.Kind="JPEG";m.Alpha="Absent";m.Checks="Marker/segment/scan bounds, supported SOF dimensions, EOI; entropy coefficients not decoded";
   }else if(ext==".wav") {
    Need(b.Length>=12&&S(b,0,4)=="RIFF"&&S(b,8,4)=="WAVE"&&LE(b,4)+8L==b.Length,"Invalid WAV RIFF bounds.");long p=12;bool fmt=false,data=false;uint size=0,rate=0;int align=0;
    while(p<b.Length){Need(p+8<=b.Length,"Truncated WAV chunk.");int i=(int)p;uint n=LE(b,i+4);long next=p+8+n+(n&1);Need(next<=b.Length,"WAV chunk/padding out of bounds.");string kind=S(b,i,4);
     if(kind=="fmt "){Need(!fmt&&n>=16&&U16(b,i+8)==1,"WAV requires single PCM fmt.");m.Channels=U16(b,i+10);m.SampleRate=LE(b,i+12);rate=LE(b,i+16);align=U16(b,i+20);m.Bits=U16(b,i+22);Need(m.Channels>0&&m.SampleRate>0&&new long[]{8,16,24,32}.Contains(m.Bits),"Invalid PCM fields.");Need(align==m.Channels*m.Bits/8&&rate==(long)m.SampleRate*align,"PCM block alignment/byte rate mismatch.");fmt=true;}
     if(kind=="data"){Need(!data,"Multiple WAV data chunks unsupported.");size=n;data=true;}p=next;
    }Need(fmt&&data&&size%align==0,"WAV fmt/data/frame bounds invalid.");m.Kind="WAV PCM";m.Duration=(double)size/rate;m.Checks="RIFF length, all chunk bounds/padding, PCM alignment/byte rate/frame count";
   }else {m.Kind="Unsupported";m.Checks="Codec inspection unavailable";}return m;
  }
 }
}
