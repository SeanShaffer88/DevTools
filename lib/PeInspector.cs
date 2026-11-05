using System;
using System.IO;
using System.Text;
using System.Collections.Generic;

namespace LocalDevTools {
 public sealed class PeSymbol { public string Name {get;set;} public uint Ordinal {get;set;} public string Forwarder {get;set;} }
 public sealed class PeImport { public string Library {get;set;} public List<PeSymbol> Symbols {get;set;} = new List<PeSymbol>(); }
 public sealed class PeInfo {
  public string Path {get;set;} public string Architecture {get;set;} public string Format {get;set;}
  public bool IsDll {get;set;} public bool HasClrHeader {get;set;}
  public List<PeSymbol> Exports {get;set;} = new List<PeSymbol>();
  public List<PeImport> Imports {get;set;} = new List<PeImport>();
 }
 public sealed class PeInspector : IDisposable {
  readonly FileStream file; readonly BinaryReader reader; readonly List<Section> sections = new List<Section>();
  struct Section { public uint Rva, VirtualSize, RawSize, Raw; }
  uint headerSize; bool plus; int totalSymbols;
  PeInspector(string path) { file = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read); reader = new BinaryReader(file); }
  public void Dispose() { reader.Dispose(); file.Dispose(); }
  void Range(long pos, long size) { if(pos < 0 || size < 0 || pos > file.Length || size > file.Length-pos) throw new InvalidDataException("PE file range is truncated or invalid."); }
  ushort U16(long pos) { Range(pos,2); file.Position=pos; return reader.ReadUInt16(); }
  uint U32(long pos) { Range(pos,4); file.Position=pos; return reader.ReadUInt32(); }
  ulong U64(long pos) { Range(pos,8); file.Position=pos; return reader.ReadUInt64(); }
  long Map(ulong rva, long size) {
   if(rva > uint.MaxValue) throw new InvalidDataException("RVA exceeds 32-bit address space.");
   if(rva < headerSize && (ulong)size <= headerSize-rva) { Range((long)rva,size); return (long)rva; }
   foreach(var s in sections) { if(rva >= s.Rva) { ulong delta=rva-s.Rva; if(delta < s.RawSize && (ulong)size <= s.RawSize-delta) { long pos=(long)s.Raw+(long)delta; Range(pos,size); return pos; } } }
   throw new InvalidDataException("RVA is outside file-backed section data.");
  }
  void VirtualTarget(uint rva) {
   if(rva<headerSize) return;
   foreach(var s in sections) { ulong span=Math.Max(s.VirtualSize,s.RawSize); if(rva>=s.Rva && (ulong)rva-s.Rva<span) return; }
   throw new InvalidDataException("Export target is outside image section address ranges.");
  }
  string Text(ulong rva) {
   var data=new List<byte>();
   for(int i=0;i<4096;i++) { long pos=Map(rva+(uint)i,1); file.Position=pos; byte b=reader.ReadByte(); if(b==0) return Encoding.ASCII.GetString(data.ToArray()); data.Add(b); }
   throw new InvalidDataException("Unterminated or oversized PE string.");
  }
  void Count(uint count,int max,string label) { if(count>max) throw new InvalidDataException(label+" exceeds safety limit."); }
  public static PeInfo Inspect(string path) { using(var p=new PeInspector(path)) return p.Read(path); }
  PeInfo Read(string path) {
   if(U16(0)!=0x5a4d) throw new InvalidDataException("Missing MZ signature.");
   long pe=U32(0x3c); if(U32(pe)!=0x4550) throw new InvalidDataException("Missing PE signature.");
   ushort machine=U16(pe+4), count=U16(pe+6), optSize=U16(pe+20), flags=U16(pe+22);
   Count(count,96,"Section count"); long opt=pe+24; Range(opt,optSize);
   ushort magic=U16(opt); if(magic!=0x10b && magic!=0x20b) throw new InvalidDataException("Only PE32/PE32+ images are supported.");
   plus=magic==0x20b; int baseSize=plus?112:96;
   if(optSize<baseSize) throw new InvalidDataException("Truncated optional header.");
   headerSize=U32(opt+60); if(headerSize>file.Length) throw new InvalidDataException("Invalid SizeOfHeaders.");
   uint dirs=U32(opt+(plus?108:92)); Count(dirs,16,"Data directory count");
   if((long)baseSize+dirs*8>optSize) throw new InvalidDataException("Data directories exceed optional header.");
   long sect=opt+optSize; Range(sect,(long)count*40);
   for(int i=0;i<count;i++) { long x=sect+i*40; var s=new Section{VirtualSize=U32(x+8),Rva=U32(x+12),RawSize=U32(x+16),Raw=U32(x+20)}; if(s.RawSize>0) Range(s.Raw,s.RawSize); sections.Add(s); }
   var result=new PeInfo{Path=System.IO.Path.GetFullPath(path),Format=plus?"PE32+":"PE32",Architecture=machine==0x14c?"x86":machine==0x8664?"x64":machine==0xaa64?"Arm64":machine==0x1c4?"Arm":"Unknown (0x"+machine.ToString("X4")+")",IsDll=(flags&0x2000)!=0};
   if(dirs>14) { uint clr=U32(opt+baseSize+14*8); uint size=U32(opt+baseSize+14*8+4); if(clr!=0 && size!=0) { Map(clr,Math.Min(size,72)); result.HasClrHeader=true; } }
   if(dirs>0) Exports(U32(opt+baseSize),U32(opt+baseSize+4),result);
   if(dirs>1) Imports(U32(opt+baseSize+8),U32(opt+baseSize+12),result);
   return result;
  }
  void Exports(uint rva,uint size,PeInfo result) {
   if(rva==0 && size==0) return; if(rva==0 || size<40) throw new InvalidDataException("Invalid export directory.");
   Map(rva,size); long d=Map(rva,40); uint ordinalBase=U32(d+16),functions=U32(d+20),names=U32(d+24),addr=U32(d+28),nameAddr=U32(d+32),ordAddr=U32(d+36);
   Count(functions,65536,"Export count"); Count(names,65536,"Export name count");
   long a=functions==0?0:Map(addr,(long)functions*4), n=names==0?0:Map(nameAddr,(long)names*4), o=names==0?0:Map(ordAddr,(long)names*2);
   var labels=new Dictionary<uint,List<string>>();
   for(uint i=0;i<names;i++) { uint index=U16(o+i*2); if(index>=functions) throw new InvalidDataException("Export ordinal index exceeds function table."); string name=Text(U32(n+i*4)); if(!labels.ContainsKey(index)) labels[index]=new List<string>(); labels[index].Add(name); }
   for(uint i=0;i<functions;i++) { uint target=U32(a+i*4); if(target==0) continue; ulong ordinal=(ulong)ordinalBase+i; if(ordinal>uint.MaxValue) throw new InvalidDataException("Export ordinal overflow."); string forward=null; if(target>=rva && (ulong)target<(ulong)rva+size) forward=Text(target); else VirtualTarget(target);
    if(labels.TryGetValue(i,out var entries)) { foreach(string name in entries) result.Exports.Add(new PeSymbol{Name=name,Ordinal=(uint)ordinal,Forwarder=forward}); }
    else result.Exports.Add(new PeSymbol{Ordinal=(uint)ordinal,Forwarder=forward});
   }
  }
  void Imports(uint rva,uint size,PeInfo result) {
   if(rva==0 && size==0) return; if(rva==0 || size<20) throw new InvalidDataException("Invalid import directory.");
   Map(rva,size); bool terminated=false;
   for(uint i=0;i<size/20;i++) { Count(i,4096,"Import descriptor count"); long d=Map((ulong)rva+i*20,20); uint lookup=U32(d),stamp=U32(d+4),chain=U32(d+8),name=U32(d+12),first=U32(d+16);
    if(lookup==0 && stamp==0 && chain==0 && name==0 && first==0) { terminated=true; break; }
    if(name==0 || (lookup==0 && first==0)) throw new InvalidDataException("Invalid import descriptor fields.");
    var item=new PeImport{Library=Text(name)}; ulong table=lookup==0?first:lookup; bool end=false;
    for(uint j=0;j<65536;j++) { int width=plus?8:4; long p=Map(table+(ulong)j*(uint)width,width); ulong thunk=plus?U64(p):U32(p); if(thunk==0) {end=true;break;} if(++totalSymbols>131072) throw new InvalidDataException("Import symbol count exceeds safety limit.");
     ulong high=plus?0x8000000000000000UL:0x80000000UL;
     if((thunk&high)!=0) item.Symbols.Add(new PeSymbol{Ordinal=(uint)(thunk&0xffff)});
     else { Map(thunk,2); item.Symbols.Add(new PeSymbol{Name=Text(thunk+2)}); }
    }
    if(!end) throw new InvalidDataException("Unterminated or oversized import thunk table."); result.Imports.Add(item);
   }
   if(!terminated) throw new InvalidDataException("Unterminated import descriptor table.");
  }
 }
}
