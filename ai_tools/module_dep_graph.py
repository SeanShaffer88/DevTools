"""Approximate Rust module/import graph with cycle and size indicators."""
from __future__ import annotations
import argparse,re
from pathlib import Path
from .common import walk_files,read_text,emit,stderr_error

MOD=re.compile(r'(?m)^\s*(?:pub(?:\([^)]*\))?\s+)?mod\s+([A-Za-z_]\w*)\s*;')
USE=re.compile(r'\buse\s+(?:crate|self|super)::([A-Za-z_]\w*)')
def main(argv=None):
 p=argparse.ArgumentParser(description=__doc__);p.add_argument("project",type=Path);p.add_argument("--text",action="store_true");a=p.parse_args(argv)
 try:
  root=a.project.resolve(strict=True); files=walk_files(root,{".rs"}); modules={}; imports={}; findings=[]
  for f in files:
   rel=f.relative_to(root).as_posix(); name=f.stem
   text=read_text(f); modules[name]=rel
   imports[name]={m.group(1) for m in USE.finditer(text)}
   for m in MOD.finditer(text):
    child=f.parent/(m.group(1)+".rs")
    if not child.exists() and not (f.parent/m.group(1)/"mod.rs").exists():
     findings.append({"code":"MissingModuleFile","path":rel,"severity":"warning","message":f"Could not locate module {m.group(1)}"})
   if len(text.splitlines())>1000:findings.append({"code":"LargeModule","path":rel,"severity":"info","message":f"Module has {len(text.splitlines())} lines"})
  graph={k:sorted(v & modules.keys()) for k,v in imports.items()}
  cycles=[]; visiting=set(); visited=set()
  def visit(n,trail):
   if n in visiting:
    cycle=trail[trail.index(n):]+[n]
    if cycle not in cycles and cycle[::-1] not in cycles:cycles.append(cycle)
    return
   if n in visited:return
   visiting.add(n)
   for nxt in graph.get(n,[]):visit(nxt,trail+[nxt])
   visiting.remove(n);visited.add(n)
  for n in graph:visit(n,[n])
  for c in cycles:findings.append({"code":"ImportCycle","path":modules.get(c[0],c[0]),"severity":"warning","message":" -> ".join(c)})
  payload={"schemaVersion":1,"tool":"ModuleDepGraph","valid":not any(x["severity"]=="error" for x in findings),
           "modules":[{"name":n,"path":modules[n],"imports":graph[n]} for n in sorted(modules)],
           "cycles":cycles,"findings":findings,"limitations":["Heuristic crate/self/super import graph; Rust name resolution and workspace crate edges are not fully resolved."]}
  emit(payload,not a.text);return 2 if cycles else 0
 except (OSError,ValueError) as e:return stderr_error(str(e))
if __name__=="__main__":raise SystemExit(main())
