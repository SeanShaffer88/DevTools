using System;
using System.IO;
using System.Text.Json;
class FakeWpr {
 static int Main(string[] args){
  var root=AppContext.BaseDirectory;File.AppendAllText(Path.Combine(root,"argv.jsonl"),JsonSerializer.Serialize(args)+Environment.NewLine);
  if(args.Length==2&&args[0]=="-help"){Console.WriteLine("-instancename supported");return 0;}
  if(args.Length<3||args[args.Length-2]!="-instancename"||!Guid.TryParse(args[args.Length-1],out var id))return 90;
  var state=Path.Combine(root,id+".state");
  if(args[0]=="-status")return 0;
  if(args[0]=="-start"){if(args[1]=="FailStart")return 5;File.WriteAllText(state,args[1]);if(args[1]=="HangStart")System.Threading.Thread.Sleep(60000);return 0;}
  if(args[0]=="-cancel"){if(!File.Exists(state))return 91;File.Delete(state);return 0;}
  if(args[0]=="-stop"){if(!File.Exists(state))return 92;if(File.ReadAllText(state)=="FailStop")return 6;File.WriteAllText(args[1],"original synthetic ETL placeholder");File.Delete(state);return 0;}
  return 93;
 }
}
