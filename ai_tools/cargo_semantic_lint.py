"""Run cargo check and clippy, returning rustc diagnostics as compact JSON."""
from __future__ import annotations
import argparse,json,subprocess
import os
from pathlib import Path
from .common import emit,stderr_error

def run(command,root,timeout):
 env=os.environ.copy();env["CARGO_NET_OFFLINE"]="true"
 try: proc=subprocess.run(command,cwd=root,capture_output=True,text=True,timeout=timeout,shell=False,env=env)
 except subprocess.TimeoutExpired as e:
  return {"command":command,"timedOut":True,"exitCode":None,"diagnostics":[],"stdout":str(e.stdout or "")[-8000:],"stderr":str(e.stderr or "")[-8000:]}
 diagnostics=[]
 for line in proc.stdout.splitlines():
  try: msg=json.loads(line)
  except json.JSONDecodeError: continue
  if msg.get("reason")=="compiler-message":
   d=msg.get("message",{}); span=next((s for s in d.get("spans",[]) if s.get("is_primary")),{})
   diagnostics.append({"level":d.get("level"),"message":d.get("message"),"code":(d.get("code") or {}).get("code"),
                       "file":span.get("file_name"),"line":span.get("line_start"),"column":span.get("column_start"),
                       "rendered":(d.get("rendered") or "").strip()[:4000]})
 priority={"error":0,"warning":1,"note":2,"help":3}
 diagnostics.sort(key=lambda d:(priority.get(d.get("level"),9),d.get("file") or "",d.get("line") or 0,d.get("column") or 0))
 return {"command":command,"exitCode":proc.returncode,"timedOut":False,"diagnostics":diagnostics,
         "stdout":proc.stdout[-8000:],"stderr":proc.stderr[-8000:]}

def main(argv=None):
 p=argparse.ArgumentParser(description=__doc__);p.add_argument("project",type=Path);p.add_argument("--timeout",type=int,default=600);p.add_argument("--allow-build-scripts",action="store_true");a=p.parse_args(argv)
 if not a.allow_build_scripts:return stderr_error("cargo may execute project build scripts; pass --allow-build-scripts to acknowledge")
 root=a.project.resolve()
 if not root.is_dir():return stderr_error("project directory does not exist")
 try:
  checks=[run(["cargo","check","--message-format=json"],root,a.timeout),run(["cargo","clippy","--message-format=json","--","-D","warnings"],root,a.timeout)]
  failed=any(x["timedOut"] or x["exitCode"]!=0 for x in checks)
  emit({"schemaVersion":1,"tool":"CargoSemanticLint","valid":not failed,"checks":checks,
        "summary":{"errorCount":sum(d["level"]=="error" for c in checks for d in c["diagnostics"]),
                   "warningCount":sum(d["level"]=="warning" for c in checks for d in c["diagnostics"])},
        "offline":True,"limitations":["Build scripts and proc macros execute in the caller's environment.","Cargo is forced into offline mode and may fail if dependencies are not cached."]})
  return 2 if failed else 0
 except OSError as e:return stderr_error(str(e))
if __name__=="__main__":raise SystemExit(main())
