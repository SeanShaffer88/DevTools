"""Generate SHA256SUMS.txt and release-name suggestions without modifying inputs."""
from __future__ import annotations
import argparse,hashlib
from pathlib import Path
from .common import emit,stderr_error,MAX_FILES

def main(argv=None):
 p=argparse.ArgumentParser(description=__doc__);p.add_argument("release_dir",type=Path);p.add_argument("--output",type=Path);p.add_argument("--text",action="store_true");a=p.parse_args(argv)
 try:
  root=a.release_dir.resolve(strict=True)
  if not root.is_dir():raise ValueError("release_dir must be a directory")
  files=[]
  for f in sorted(root.rglob("*")):
   if f.is_symlink():raise ValueError(f"symlinks are refused: {f.relative_to(root)}")
   if f.is_file() and f.name!="SHA256SUMS.txt":
    files.append(f)
    if len(files)>MAX_FILES:raise ValueError(f"more than {MAX_FILES} files")
  rows=[]
  for f in files:
   h=hashlib.sha256()
   with f.open("rb") as stream:
    for chunk in iter(lambda:stream.read(1024*1024),b""):h.update(chunk)
   rows.append(f"{h.hexdigest()}  {f.relative_to(root).as_posix()}")
  manifest="\n".join(rows)+("\n" if rows else "")
  written=None
  if a.output:
   dest=a.output.resolve()
   if dest.exists():raise ValueError(f"refusing to overwrite existing output: {dest}")
   dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(manifest,encoding="utf-8");written=str(dest)
  suggestions=[]
  for f in files:
   name=f.name
   if name.lower().endswith((".exe",".msi")):suggestions.append({"source":f.relative_to(root).as_posix(),"suggested":f.stem+"-x64-Setup"+f.suffix})
   elif name.lower().endswith(".zip"):suggestions.append({"source":f.relative_to(root).as_posix(),"suggested":f.stem+"-x64-Portable.zip"})
  emit({"schemaVersion":1,"tool":"ReleaseManifestGen","fileCount":len(files),"manifest":manifest,"writtenTo":written,
        "renameSuggestions":suggestions,"limitations":["Suggestions are not applied; artifact architecture/type is not inspected."]},not a.text)
  return 0
 except (OSError,ValueError) as e:return stderr_error(str(e))
if __name__=="__main__":raise SystemExit(main())
