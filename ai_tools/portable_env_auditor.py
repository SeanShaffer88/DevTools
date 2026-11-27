"""Heuristic offline/telemetry/write-scope scanner for source files."""
from __future__ import annotations
import argparse,re
from pathlib import Path
from .common import walk_files,read_text,finding,finish

SUFFIXES={".py",".rs",".ps1",".psm1",".cs",".js",".ts",".gd",".lua",".toml",".json",".yml",".yaml"}
NETWORK=re.compile(r'https?://|wss?://|(?:telemetry|analytics|tracking|sentry|segment|mixpanel|amplitude)',re.I)
WRITE=re.compile(r'\b(?:write_text|write_bytes|open|(?:std::)?fs::write|File\.(?:Write|Append|Create)|MoveFile|CreateFile|mkdir|makedirs)\b',re.I)
def main(argv=None):
 p=argparse.ArgumentParser(description=__doc__);p.add_argument("root",type=Path);p.add_argument("--max-files",type=int,default=20000);p.add_argument("--text",action="store_true");a=p.parse_args(argv)
 root=a.root.resolve(); findings=[]
 for f in walk_files(root,SUFFIXES,a.max_files):
  text=read_text(f);rel=f.relative_to(root).as_posix()
  for line_no,line in enumerate(text.splitlines(),1):
   if NETWORK.search(line): findings.append(finding("NetworkOrTelemetryMarker",rel,"warning","URL or telemetry-related token found; inspect context",line=line_no))
   if WRITE.search(line) and re.search(r'(?i)(?:[A-Z]:\\\\|/home/|/tmp/|AppData|ProgramData|Path\.home|GetTempPath)',line):
    findings.append(finding("PotentialBroadWrite",rel,"warning","Write API and non-local path occur on the same line",line=line_no))
 return finish("PortableEnvAuditor",findings,a.text,filesScanned=len(walk_files(root,SUFFIXES,a.max_files)),
   limitation="Static text scan only. A clean scan cannot prove zero network access, telemetry, or bounded filesystem writes.")
if __name__=="__main__":raise SystemExit(main())
