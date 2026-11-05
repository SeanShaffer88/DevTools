using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Reflection;
using System.Reflection.Metadata;
using System.Reflection.Metadata.Ecma335;
using System.Reflection.PortableExecutable;

namespace DevToolsQualityNative {
 public sealed class ApiDump { public string Identity; public string[] Surface; }
 public sealed class MetadataDecoder : ISignatureTypeProvider<string,object> {
  MetadataReader r; int operations; readonly SortedSet<string> rows=new SortedSet<string>(StringComparer.Ordinal);
  void Tick(){if(++operations>100000)throw new NotSupportedException("Signature operation limit");}
  string S(StringHandle h){var s=r.GetString(h);if(s.Length>4096)throw new NotSupportedException("String limit");return s;}
  string Name(TypeDefinitionHandle h,int depth=0){if(depth>32)throw new NotSupportedException("Nested type limit");var t=r.GetTypeDefinition(h);var parent=t.GetDeclaringType();return parent.IsNil?S(t.Namespace)+"."+S(t.Name):Name(parent,depth+1)+"+"+S(t.Name);}
  bool Visible(TypeDefinitionHandle h,int depth=0){if(depth>32)throw new NotSupportedException();var t=r.GetTypeDefinition(h);var v=t.Attributes&TypeAttributes.VisibilityMask;var p=t.GetDeclaringType();return p.IsNil?v==TypeAttributes.Public:(v==TypeAttributes.NestedPublic||v==TypeAttributes.NestedFamily||v==TypeAttributes.NestedFamORAssem)&&Visible(p,depth+1);}
  static bool Visible(MethodAttributes a){var v=a&MethodAttributes.MemberAccessMask;return v==MethodAttributes.Public||v==MethodAttributes.Family||v==MethodAttributes.FamORAssem;}
  static bool Visible(FieldAttributes a){var v=a&FieldAttributes.FieldAccessMask;return v==FieldAttributes.Public||v==FieldAttributes.Family||v==FieldAttributes.FamORAssem;}
  string Entity(EntityHandle h){Tick();if(h.IsNil)return "";switch(h.Kind){case HandleKind.TypeDefinition:return Name((TypeDefinitionHandle)h);case HandleKind.TypeReference:return Ref((TypeReferenceHandle)h,0);case HandleKind.TypeSpecification:return r.GetTypeSpecification((TypeSpecificationHandle)h).DecodeSignature(this,null);default:if(h.IsNil)return "";throw new NotSupportedException("Unsupported type handle");}}
  string Ref(TypeReferenceHandle h,int depth){if(depth>32)throw new NotSupportedException();var t=r.GetTypeReference(h);string scope=t.ResolutionScope.Kind==HandleKind.AssemblyReference?"["+S(r.GetAssemblyReference((AssemblyReferenceHandle)t.ResolutionScope).Name)+"]":"";return t.ResolutionScope.Kind==HandleKind.TypeReference?Ref((TypeReferenceHandle)t.ResolutionScope,depth+1)+"+"+S(t.Name):scope+S(t.Namespace)+"."+S(t.Name);}
  string Constant(ConstantHandle h){if(h.IsNil)return "";var c=r.GetConstant(h);var b=r.GetBlobBytes(c.Value);if(b.Length>65536)throw new NotSupportedException();return c.TypeCode+":"+Convert.ToHexString(b);}
  string Generics(GenericParameterHandleCollection handles){var list=new List<string>();foreach(var h in handles){var g=r.GetGenericParameter(h);var constraints=new List<string>();foreach(var ch in g.GetConstraints())constraints.Add(Entity(r.GetGenericParameterConstraint(ch).Type));constraints.Sort(StringComparer.Ordinal);list.Add(g.Index+":"+g.Attributes+":"+string.Join("&",constraints));}return string.Join(";",list);}
  string Accessor(MethodDefinitionHandle h){if(h.IsNil)return "none";var m=r.GetMethodDefinition(h);return (m.Attributes&MethodAttributes.MemberAccessMask).ToString();}
  bool AccessVisible(MethodDefinitionHandle h){return !h.IsNil&&Visible(r.GetMethodDefinition(h).Attributes);}
  void Blob(BlobHandle h){if(r.GetBlobReader(h).Length>65536)throw new NotSupportedException("Signature size limit");}
  public static ApiDump Read(string path){return new MetadataDecoder().ReadCore(path);}
  ApiDump ReadCore(string path){using(var f=File.OpenRead(path)){if(f.Length>16777216)throw new NotSupportedException("Input size limit");using(var pe=new PEReader(f,PEStreamOptions.PrefetchMetadata)){if(!pe.HasMetadata)throw new NotSupportedException("No CLI metadata");r=pe.GetMetadataReader();if(!r.IsAssembly)throw new NotSupportedException("Not assembly");foreach(TableIndex t in Enum.GetValues(typeof(TableIndex)))if(r.GetTableRowCount(t)>100000)throw new NotSupportedException("Table limit");if(r.ExportedTypes.Count>0)throw new NotSupportedException("Forwarded/exported types unsupported");
   var assembly=r.GetAssemblyDefinition();string identity=S(assembly.Name)+", Version="+assembly.Version+", Culture="+S(assembly.Culture)+", Key="+Convert.ToHexString(r.GetBlobBytes(assembly.PublicKey));
   foreach(var th in r.TypeDefinitions){Tick();if(!Visible(th))continue;var t=r.GetTypeDefinition(th);string name=Name(th);var interfaces=new List<string>();foreach(var ih in t.GetInterfaceImplementations())interfaces.Add(Entity(r.GetInterfaceImplementation(ih).Interface));interfaces.Sort(StringComparer.Ordinal);
    rows.Add("T|"+name+"|"+t.Attributes+"|base="+Entity(t.BaseType)+"|interfaces="+string.Join(",",interfaces)+"|generic="+Generics(t.GetGenericParameters()));
    foreach(var mh in t.GetMethods()){Tick();var m=r.GetMethodDefinition(mh);if(!Visible(m.Attributes))continue;Blob(m.Signature);var sig=m.DecodeSignature(this,null);var pars=new List<string>();foreach(var ph in m.GetParameters()){var p=r.GetParameter(ph);pars.Add(p.SequenceNumber+":"+p.Attributes+":"+Constant(p.GetDefaultValue()));}
     rows.Add("M|"+name+"|"+S(m.Name)+"|"+m.Attributes+"|"+sig.Header.RawValue+"|arity="+sig.GenericParameterCount+"|"+sig.ReturnType+"("+string.Join(",",sig.ParameterTypes)+")|generic="+Generics(m.GetGenericParameters())+"|params="+string.Join(";",pars));}
    foreach(var fh in t.GetFields()){Tick();var field=r.GetFieldDefinition(fh);if(!Visible(field.Attributes))continue;Blob(field.Signature);rows.Add("F|"+name+"|"+S(field.Name)+"|"+field.Attributes+"|"+field.DecodeSignature(this,null)+"|constant="+Constant(field.GetDefaultValue()));}
    foreach(var ph in t.GetProperties()){Tick();var prop=r.GetPropertyDefinition(ph);var acc=prop.GetAccessors();if(!AccessVisible(acc.Getter)&&!AccessVisible(acc.Setter))continue;Blob(prop.Signature);var sig=prop.DecodeSignature(this,null);rows.Add("P|"+name+"|"+S(prop.Name)+"|"+sig.ReturnType+"("+string.Join(",",sig.ParameterTypes)+")|get="+Accessor(acc.Getter)+"|set="+Accessor(acc.Setter)+"|constant="+Constant(prop.GetDefaultValue()));}
    foreach(var eh in t.GetEvents()){Tick();var ev=r.GetEventDefinition(eh);var acc=ev.GetAccessors();if(!AccessVisible(acc.Adder)&&!AccessVisible(acc.Remover)&&!AccessVisible(acc.Raiser))continue;rows.Add("E|"+name+"|"+S(ev.Name)+"|"+Entity(ev.Type)+"|add="+Accessor(acc.Adder)+"|remove="+Accessor(acc.Remover)+"|raise="+Accessor(acc.Raiser));}
   }
   if(rows.Count>20000)throw new NotSupportedException("Surface limit");return new ApiDump{Identity=identity,Surface=rows.ToArray()};
  }}}
  public string GetArrayType(string e,ArrayShape s){Tick();return e+"[rank="+s.Rank+";sizes="+string.Join(",",s.Sizes)+";lower="+string.Join(",",s.LowerBounds)+"]";}
  public string GetByReferenceType(string e){Tick();return e+"&";}
  public string GetFunctionPointerType(MethodSignature<string> s){throw new NotSupportedException("Function pointers unsupported");}
  public string GetGenericInstantiation(string e,ImmutableArray<string> args){Tick();return e+"<"+string.Join(",",args)+">";}
  public string GetGenericMethodParameter(object c,int i){Tick();return "!!"+i;}
  public string GetGenericTypeParameter(object c,int i){Tick();return "!"+i;}
  public string GetModifiedType(string m,string e,bool required){Tick();return e+(required?" modreq(":" modopt(")+m+")";}
  public string GetPinnedType(string e){throw new NotSupportedException("Pinned API signature unsupported");}
  public string GetPointerType(string e){Tick();return e+"*";}
  public string GetPrimitiveType(PrimitiveTypeCode c){Tick();return c.ToString();}
  public string GetSZArrayType(string e){Tick();return e+"[]";}
  public string GetTypeFromDefinition(MetadataReader reader,TypeDefinitionHandle h,byte k){Tick();return Name(h);}
  public string GetTypeFromReference(MetadataReader reader,TypeReferenceHandle h,byte k){Tick();return Ref(h,0);}
  public string GetTypeFromSpecification(MetadataReader reader,object c,TypeSpecificationHandle h,byte k){Tick();Blob(reader.GetTypeSpecification(h).Signature);return reader.GetTypeSpecification(h).DecodeSignature(this,c);}
 }
}
