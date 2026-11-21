"""Validate declared export profiles without invoking build or signing tools."""
from __future__ import annotations
import argparse,json,re
from pathlib import Path
from .common import emit,finding,stderr_error

SUPPORTED={"windows-x64","android-x86_64","linux-x64"}
def main(argv=None):
 p=argparse.ArgumentParser(description=__doc__);p.add_argument("project",type=Path);p.add_argument("--profiles",type=Path,required=True);a=p.parse_args(argv)
 try:
  root=a.project.resolve(strict=True); data=json.loads(a.profiles.read_text(encoding="utf-8-sig"))
  if not isinstance(data,dict) or not isinstance(data.get("profiles"),list):raise ValueError("profiles JSON must contain a profiles array")
  findings=[]; seen=set()
  presets=(root/"export_presets.cfg").exists(); cargo=(root/"Cargo.toml").exists()
  for i,row in enumerate(data["profiles"]):
   if not isinstance(row,dict): findings.append(finding("InvalidProfile",str(i),"error","Profile must be an object"));continue
   target=row.get("target","")
   if target in seen:findings.append(finding("DuplicateTarget",str(i),"error",f"Duplicate target: {target}"))
   seen.add(target)
   if target not in SUPPORTED:findings.append(finding("UnsupportedTarget",str(i),"error",f"Unsupported target {target!r}; allowed: {', '.join(sorted(SUPPORTED))}"))
   if target=="windows-x64" and not re.search(r'win(?:dows)?\s*11|windows-x64',str(row.get("os","windows 11 x64")),re.I):
    findings.append(finding("WindowsTargetMismatch",str(i),"error","Windows profile must target Windows 11 x64"))
   if row.get("engine")=="godot" and not presets:findings.append(finding("MissingExportPresets","export_presets.cfg","error","Godot export profile declared but presets file is missing"))
   if row.get("engine")=="rust" and not cargo:findings.append(finding("MissingCargoManifest","Cargo.toml","error","Rust profile declared but Cargo.toml is missing"))
   if target.startswith("android") and row.get("signingRequired") and not row.get("signingConfigured"):
    findings.append(finding("SigningNotConfigured",str(i),"error","Signing required but configuration presence is not declared"))
   if target.startswith("android") and row.get("packageName") and (not isinstance(row["packageName"],str) or not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+",row["packageName"])):
    findings.append(finding("InvalidPackageName",str(i),"error","Android packageName is not a dotted identifier"))
   if target.startswith("windows") and row.get("architecture","x64")!="x64":
    findings.append(finding("ArchitectureMismatch",str(i),"error","Only x64 is supported"))
  emit({"schemaVersion":1,"tool":"ExportMatrix","valid":not any(x["severity"]=="error" for x in findings),
        "profilesChecked":len(data["profiles"]),"findings":findings,"buildsRun":False,"signingPerformed":False,
        "limitations":["This validates configuration declarations only; it does not prove a toolchain can build or sign the artifact."]})
  return 2 if any(x["severity"]=="error" for x in findings) else 0
 except (OSError,ValueError,json.JSONDecodeError) as e:return stderr_error(str(e))
if __name__=="__main__":raise SystemExit(main())
