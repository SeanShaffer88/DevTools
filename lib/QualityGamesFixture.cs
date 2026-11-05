using System;using System.IO;using System.Text.Json;using System.Text;using System.Security.Cryptography;using System.Collections.Generic;using System.Threading;
class Program {
 static string Hash(int score){return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes("{\"score\":"+score+"}"))).ToLowerInvariant();}
 static int Main(string[] args){string mode=Environment.GetEnvironmentVariable("QG_TEST_MODE")??"ok";if(args.Length>0&&args[0]=="replay")mode=args[1];string log=Environment.GetEnvironmentVariable("QG_TEST_LOG");if(!string.IsNullOrEmpty(log))File.AppendAllText(log,JsonSerializer.Serialize(args)+"\n");if(mode=="timeout"){Thread.Sleep(10000);return 0;}if(mode=="overflow"){Console.Write(new string('X',1200000));return 0;}if(mode=="exit")return 7;
 if(args.Length>0&&args[0]=="replay"){
  using var doc=JsonDocument.Parse(Console.In.ReadToEnd());var root=doc.RootElement;if(root.GetProperty("schemaVersion").GetInt32()!=1)return 8;if(mode=="invalid"){Console.Write("{}");return 0;}if(mode=="empty")return 0;if(mode=="wrongcase"){Console.Write("{\"SchemaVersion\":1,\"states\":[],\"assertions\":[]}");return 0;}
  int score=root.TryGetProperty("initialState",out var initial)?initial.GetProperty("score").GetInt32():0;var states=new List<object>();foreach(var ev in root.GetProperty("events").EnumerateArray()){if(ev.GetProperty("type").GetString()=="Advance")score+=ev.GetProperty("data").GetProperty("amount").GetInt32();if(mode=="nondeterministic")score+=Random.Shared.Next(1,100000000);states.Add(new{tick=ev.GetProperty("tick").GetInt32(),stateHash=mode=="badhash"?new string('0',64):Hash(score),state=new{score}});}
  var assertions=mode=="missingrule"?new object[0]:new object[]{new{id="progression",passed=mode!="badrule"}};Console.Write(JsonSerializer.Serialize(new{schemaVersion=1,states,assertions,saveLoad=new{beforeHash=Hash(score),afterHash=mode=="badsave"?new string('0',64):Hash(score)}}));return 0;
 }
 if(args.Length>0&&args[0]=="bridge"){
  using var doc=JsonDocument.Parse(Console.In.ReadToEnd());string action=doc.RootElement.GetProperty("action").GetString();if(doc.RootElement.GetProperty("deviceSerial").GetString()!="fixture:123")return 9;Console.Write(JsonSerializer.Serialize(new{schemaVersion=1,packageName=mode=="wrongtarget"?"other.app":"local.fixture",action,passed=mode!="bridgefail",values=new{score=mode=="persistencefail"?9:3}}));return 0;
 }
 if(args.Length<3||args[0]!="-s"||args[1]!="fixture:123")return 10;
 string command=string.Join(" ",args,2,args.Length-2);
 switch(command){case "get-state":Console.WriteLine(mode=="offline"?"offline":"device");break;case "shell dumpsys activity activities":Console.WriteLine("mResumedActivity: ActivityRecord{abc u0 "+(mode=="otherapp"?"other.app":"local.fixture")+"/.MainActivity t1}");break;case "shell input keyevent KEYCODE_HOME":break;case "shell am force-stop local.fixture":break;case "shell am start -W -n local.fixture/.MainActivity":if(mode=="amerror")Console.WriteLine("Error: Activity not started");else if(mode=="amtimeout")Console.WriteLine("Status: timeout");else if(mode!="blank")Console.WriteLine("Status: ok");break;default:Console.Error.WriteLine("Unexpected argv: "+command);return 11;}return 0;
 }
}
