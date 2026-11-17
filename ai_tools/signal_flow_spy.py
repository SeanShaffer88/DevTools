"""Static signal declaration/emission/connection index for Godot scripts/scenes."""
from __future__ import annotations
import argparse,re
from pathlib import Path
from .common import walk_files,read_text,finding,finish

def autoloads(root):
 """Map [autoload] names in project.godot to their res:// targets (static read only)."""
 cfg=root/"project.godot"; names={}; section=None
 if not cfg.is_file(): return names
 for line in read_text(cfg).splitlines():
  s=line.strip(); h=re.match(r'^\[([^\]]+)\]$',s)
  if h: section=h.group(1).strip(); continue
  m=re.match(r'^([A-Za-z_]\w*)\s*=\s*"\*?(res://[^"]*)"',s) if section=="autoload" else None
  if m: names[m.group(1)]=m.group(2)
 return names

def main(argv=None):
 p=argparse.ArgumentParser(description=__doc__);p.add_argument("project",type=Path);p.add_argument("--text",action="store_true");a=p.parse_args(argv)
 root=a.project.resolve(); files=walk_files(root,{".gd",".cs",".tscn"}); declared={}; emitted=[]; connected=[]; findings=[]; texts={}; local={}
 loads=autoloads(root)
 for f in files:
  text=read_text(f); rel=f.relative_to(root).as_posix(); texts[rel]=text
  for m in re.finditer(r'^\s*signal\s+([A-Za-z_]\w*)\s*(?:\(([^)]*)\))?',text,re.M):
   declared[m.group(1)]=(rel,len(text[:m.start()].splitlines())+1, len([x for x in m.group(2).split(",") if x.strip()]) if m.group(2) else 0)
   if not rel.endswith(".tscn"): local.setdefault(rel,set()).add(m.group(1))
  for m in re.finditer(r'\b(?:public|protected|internal|private)?\s*event\s+(?:Action(?:<([^>]+)>)?|EventHandler(?:<[^>]+>)?)\s+([A-Za-z_]\w*)',text):
   declared[m.group(2)]=(rel,len(text[:m.start()].splitlines())+1,len(m.group(1).split(",")) if m.group(1) else 0)
  for m in re.finditer(r'\bemit_signal\s*\(\s*["\']([^"\']+)',text):
   emitted.append({"signal":m.group(1),"path":rel})
  for m in re.finditer(r'\b([A-Za-z_]\w*)\s*(?:\?\.Invoke|\.Invoke)\s*\(',text):
   if m.group(1) in declared: emitted.append({"signal":m.group(1),"path":rel})
  for m in re.finditer(r'\.connect\s*\(\s*["\']([^"\']+)',text):
   connected.append({"signal":m.group(1),"path":rel})
  for m in re.finditer(r'\b([A-Za-z_]\w*)\s*\+=\s*[A-Za-z_]',text):
   if m.group(1) in declared: connected.append({"signal":m.group(1),"path":rel})
  for m in re.finditer(r'\bsignal\s*=\s*"([^"]+)"',text):
   connected.append({"signal":m.group(1),"path":rel})
  for m in re.finditer(r'^\s*signal\s+([A-Za-z_]\w*)\s*;',text,re.M):
   declared.setdefault(m.group(1),(rel,len(text[:m.start()].splitlines())+1,0))
 # Godot 4 Signal-object references: own-script `sig.emit(...)`/`self.sig.connect(...)`, and
 # `<Autoload>.sig.emit/connect(...)` where <Autoload> is registered in project.godot [autoload].
 for rel,text in texts.items():
  if not rel.endswith(".gd"): continue
  for m in re.finditer(r'(?<![\w.])(?:self\.)?([A-Za-z_]\w*)\.(emit|connect)\s*\(',text):
   if m.group(1) in local.get(rel,()):
    (emitted if m.group(2)=="emit" else connected).append({"signal":m.group(1),"path":rel,"via":"self"})
  for m in re.finditer(r'(?<![\w.])([A-Za-z_]\w*)\.([A-Za-z_]\w*)\.(emit|connect)\s*\(',text):
   if m.group(1) in loads:
    (emitted if m.group(3)=="emit" else connected).append({"signal":m.group(2),"path":rel,"via":"autoload:"+m.group(1)})
 names=set(declared)
 for row in emitted:
  if row["signal"] not in names and "via" not in row: findings.append(finding("UndeclaredEmission",row["path"],"warning",f"Emits undeclared signal {row['signal']}"))
 for row in connected:
  if row["signal"] not in names and "via" not in row: findings.append(finding("UnknownConnection",row["path"],"warning",f"Connects undeclared signal {row['signal']}"))
 for name,(path,line,arity) in declared.items():
  hits=sum(x["signal"]==name for x in emitted+connected)
  if hits==0: findings.append(finding("UnreferencedSignal",path,"info",f"Signal {name} has no detected emit/connect",line=line,arity=arity))
 return finish("SignalFlowSpy",findings,a.text,signals=[{"name":n,"path":v[0],"line":v[1],"declaredArity":v[2]} for n,v in sorted(declared.items())],emissions=emitted,connections=connected,autoloads=loads,
   limitation="Regex-based GDScript/C# scan; own-script and project.godot autoload Signal references are resolved, but instance-variable receivers, dynamic connections, callable signatures and inherited signals are not.")
if __name__=="__main__": raise SystemExit(main())
