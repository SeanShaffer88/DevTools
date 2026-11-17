"""Run a selected Godot headless test entrypoint with bounded JSON evidence."""
from __future__ import annotations
import argparse,subprocess,shutil
from pathlib import Path
from .common import emit,stderr_error

def main(argv=None):
 p=argparse.ArgumentParser(description=__doc__);p.add_argument("project",type=Path);p.add_argument("--godot",required=True);p.add_argument("--test-script",required=True);p.add_argument("--timeout",type=int,default=300);p.add_argument("--allow-project-code",action="store_true");a=p.parse_args(argv)
 if not a.allow_project_code: return stderr_error("Refusing to execute project code without --allow-project-code")
 try:
  root=a.project.resolve(strict=True); test=(root/a.test_script).resolve(strict=True)
  if root not in test.parents: raise ValueError("test script must be inside project")
  godot=Path(a.godot)
  executable=str(godot.resolve()) if godot.exists() else shutil.which(a.godot)
  if not executable: raise FileNotFoundError(f"Godot executable not found: {a.godot}")
  cmd=[executable,"--headless","--path",str(root),"--script",str(test)]
  run=subprocess.run(cmd,capture_output=True,text=True,timeout=max(1,min(a.timeout,3600)),shell=False)
  out={"schemaVersion":1,"tool":"GTHarness","exitCode":run.returncode,"passed":run.returncode==0,"command":cmd,
       "stdout":run.stdout[-20000:],"stderr":run.stderr[-20000:],
       "assertionFailures":[x for x in (run.stdout+"\n"+run.stderr).splitlines() if "assert" in x.lower() and any(w in x.lower() for w in ("fail","error"))],
       "limitations":["Runs project code; not a sandbox.","Output truncated to final 20,000 characters per stream."]}
  emit(out); return 0 if out["passed"] else 2
 except subprocess.TimeoutExpired as e:
  emit({"schemaVersion":1,"tool":"GTHarness","passed":False,"timedOut":True,"timeoutSeconds":a.timeout,
        "stdout":str(e.stdout or "")[-20000:],"stderr":str(e.stderr or "")[-20000:]});return 2
 except (OSError,ValueError) as e:return stderr_error(str(e))
if __name__=="__main__":raise SystemExit(main())
