"""Inspect the safe Lua literal subset used by WoW SavedVariables (never execute Lua)."""
from __future__ import annotations
import argparse,json,re
from pathlib import Path
from .common import emit,finding,finish,stderr_error

TOKEN=re.compile(r'\s*(--[^\n]*(?:\n|$)|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|[A-Za-z_]\w*|-?\d+(?:\.\d+)?|[{}=\[\],;])')
class Parser:
 def __init__(self,text):
  self.t=[]; self.i=0; pos=0
  for m in TOKEN.finditer(text):
   if text[pos:m.start()].strip(): raise ValueError(f"unsupported character near offset {pos}")
   pos=m.end()
   if not m.group(1).startswith("--"): self.t.append(m.group(1))
  if text[pos:].strip(): raise ValueError(f"unsupported character near offset {pos}")
 def pop(self): x=self.t[self.i];self.i+=1;return x
 def peek(self): return self.t[self.i] if self.i<len(self.t) else ""
 def value(self,depth=0):
  if depth>64: raise ValueError("table nesting exceeds 64")
  x=self.pop()
  if x=="{":
   out={}
   while self.peek() and self.peek()!="}":
    if self.peek()=="[": self.pop(); k=self.value(depth+1); self.pop(); self.pop()
    elif self.i+1<len(self.t) and re.fullmatch(r"[A-Za-z_]\w*",self.peek()) and self.t[self.i+1]=="=": k=self.pop();self.pop()
    else: k=len(out)+1
    v=self.value(depth+1)
    if any(type(existing) is type(k) and existing == k for existing in out): raise ValueError(f"duplicate key: {k}")
    out[k]=v
    if self.peek() in {",",";"}: self.pop()
    elif self.peek()!="}": raise ValueError("expected comma or closing brace")
   if self.pop()!="}": raise ValueError("unterminated table")
   return out
  if x in {"true","false"}: return x=="true"
  if x=="nil": return None
  if x.startswith(("'",'"')): return bytes(x[1:-1],"utf-8").decode("unicode_escape")
  if re.fullmatch(r"-?\d+(?:\.\d+)?",x): return float(x) if "." in x else int(x)
  raise ValueError(f"unsupported Lua literal: {x}")
def main(argv=None):
 p=argparse.ArgumentParser(description=__doc__);p.add_argument("file",type=Path);p.add_argument("--max-bytes",type=int,default=4*1024*1024);p.add_argument("--schema",type=Path,help="JSON object with requiredKeys for top-level tables");p.add_argument("--sanitize-json",type=Path,help="write parsed literal data as JSON to a new path");p.add_argument("--json-data",action="store_true",help="include parsed JSON-compatible data");p.add_argument("--text",action="store_true");a=p.parse_args(argv)
 try:
  raw=a.file.read_text(encoding="utf-8-sig")
  if len(raw.encode("utf-8"))>a.max_bytes: raise ValueError("input exceeds configured byte limit")
  # Ignore Lua comments and permit one or more VariableName = { ... } assignments.
  clean=raw
  assignments=re.findall(r'(?m)^\s*([A-Za-z_]\w*)\s*=\s*(\{)',clean)
  findings=[]; values={}
  for name,_ in assignments:
   start=re.search(r'(?m)^\s*'+re.escape(name)+r'\s*=\s*\{',clean)
   if not start: continue
   parser=Parser(clean[start.end()-1:]); values[name]=parser.value()
  if not values: raise ValueError("no simple top-level SavedVariables table assignment found")
  stats={"tables":0,"keys":0,"maxDepth":0}
  def count(v,d=0):
   stats["maxDepth"]=max(stats["maxDepth"],d)
   if isinstance(v,dict):
    stats["tables"]+=1;stats["keys"]+=len(v)
    for k,x in v.items():
     if isinstance(k,str) and not k: findings.append(finding("EmptyKey",a.file.name,"warning","Empty table key found"))
     count(x,d+1)
  for v in values.values(): count(v)
  if a.schema:
   expected=json.loads(a.schema.read_text(encoding="utf-8-sig"))
   required=expected.get("requiredKeys",[]) if isinstance(expected,dict) else None
   if not isinstance(required,list) or any(not isinstance(k,str) for k in required): raise ValueError("schema must be an object with requiredKeys: string[]")
   for name,value in values.items():
    if isinstance(value,dict):
     for key in required:
      if key not in value: findings.append(finding("SchemaDrift",name,"warning",f"Required key {key!r} is missing"))
  parsed_json=json.dumps(values,ensure_ascii=False,separators=(",",":"))
  stats["inputBytes"]=len(raw.encode("utf-8"));stats["parsedJsonBytes"]=len(parsed_json.encode("utf-8"))
  if stats["parsedJsonBytes"]>a.max_bytes: findings.append(finding("ExpandedDataSize",a.file.name,"warning","Normalized JSON exceeds configured input byte budget",bytes=stats["parsedJsonBytes"],maxBytes=a.max_bytes))
  written=None
  if a.sanitize_json:
   dest=a.sanitize_json.resolve()
   if dest.exists(): raise ValueError(f"refusing to overwrite existing output: {dest}")
   dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(json.dumps(values,ensure_ascii=False,indent=2)+"\n",encoding="utf-8");written=str(dest)
  payload={"schemaVersion":1,"tool":"SavedVariablesInspector","valid":not any(x.get("severity")=="error" for x in findings),"variables":sorted(values),"stats":stats,"findings":findings,
           "sanitizedJsonWrittenTo":written,"limitation":"Parses literal tables only; expressions, metatables, and Lua execution are unsupported."}
  if a.json_data: payload["data"]=values
  emit(payload,not a.text);return 0
 except (OSError,ValueError,IndexError) as e:return stderr_error(str(e))
if __name__=="__main__":raise SystemExit(main())
