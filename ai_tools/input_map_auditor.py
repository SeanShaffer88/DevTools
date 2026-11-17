"""Compare project.godot InputMap actions with script input calls."""
from __future__ import annotations
import argparse,re
from pathlib import Path
from .common import walk_files,read_text,finding,finish

def main(argv=None):
 p=argparse.ArgumentParser(description=__doc__);p.add_argument("project",type=Path);p.add_argument("--text",action="store_true");a=p.parse_args(argv)
 root=a.project.resolve(); cfg=root/"project.godot"; findings=[]
 if not cfg.is_file(): return finish("InputMapAuditor",[finding("MissingProjectConfig","project.godot","error","Godot project.godot not found")],a.text)
 text=read_text(cfg); actions=set(re.findall(r'^\s*([A-Za-z_]\w*)\s*=\s*\{',text,re.M))
 used=set(); hardcoded=[]
 for f in walk_files(root,{".gd",".cs"}):
  code=read_text(f); rel=f.relative_to(root).as_posix()
  for m in re.finditer(r'(?:is_action(?:_just_(?:pressed|released))?|get_action_strength)\s*\(\s*["\']([^"\']+)',code):
   used.add(m.group(1))
   if m.group(1) not in actions: findings.append(finding("MissingInputAction",rel,"error",f"Input action {m.group(1)!r} is absent from project.godot"))
  if re.search(r'\bKEY_[A-Z0-9_]+|\bKeyCode\.[A-Za-z]+',code):
   hardcoded.append(rel)
 for name in sorted(actions-used):
  findings.append(finding("UnusedInputAction","project.godot","info",f"Action {name!r} has no detected script use"))
 for rel in sorted(set(hardcoded)): findings.append(finding("HardcodedKey","/"+rel,"warning","Key constant found; verify intentional remapping behavior"))
 return finish("InputMapAuditor",findings,a.text,actions=sorted(actions),usedActions=sorted(used),
   limitation="Static string matching; indirect calls and generated input maps are not resolved.")
if __name__=="__main__":raise SystemExit(main())
