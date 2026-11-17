"""Heuristic WoW Lua taint-risk scan; findings require manual review."""
from __future__ import annotations
import argparse,re
from pathlib import Path
from .common import walk_files,read_text,finding,finish

RULES=[
 ("SecureHookShadowing",re.compile(r'\bhooksecurefunc\s*\(\s*([A-Za-z_]\w*)\s*,\s*function'),"Anonymous hook may hide ownership/signature context; prefer named, narrow hooks."),
 ("ProtectedGlobalWrite",re.compile(r'(?m)^\s*(?:_G|_G\s*\[)[^\n]*?=\s*'),"Assignment to global namespace may pollute protected state."),
 ("ProtectedActionAPI",re.compile(r'\b(?:CastSpellByName|UseAction|TargetUnit|RunMacroText)\s*\('),"Protected action API call requires secure context and combat review."),
 ("CombatFrameMutation",re.compile(r'\b(?:SetAttribute|SetParent|Hide|Show|SetPoint|ClearAllPoints)\s*\('),"Frame mutation may be restricted during combat lockdown."),
 ("DynamicCode",re.compile(r'\b(?:loadstring|load)\s*\('),"Dynamic Lua compilation complicates taint and trust analysis."),
]
def main(argv=None):
 p=argparse.ArgumentParser(description=__doc__);p.add_argument("addon",type=Path);p.add_argument("--text",action="store_true");a=p.parse_args(argv)
 root=a.addon.resolve(); findings=[]
 for f in walk_files(root,{".lua"}):
  text=read_text(f); rel=f.relative_to(root).as_posix()
  # Strip line comments conservatively; strings may still cause false positives.
  code="\n".join(line.split("--",1)[0] for line in text.splitlines())
  for code_name,rx,msg in RULES:
   for m in rx.finditer(code):
    findings.append(finding(code_name,rel,"warning",msg,line=code.count("\n",0,m.start())+1))
 return finish("AddonMemoryTaintAuditor",findings,a.text,
  limitation="Regex audit only: WoW taint propagation, secure templates, control flow, and combat state are not modeled.")
if __name__=="__main__":raise SystemExit(main())
