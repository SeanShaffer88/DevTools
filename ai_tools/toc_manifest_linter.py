"""Validate WoW TOC metadata, load order, path existence, and interface version."""
from __future__ import annotations
import argparse,re
from pathlib import Path
import xml.etree.ElementTree as ET
from .common import read_text,finding,finish,project_path

REQUIRED=("Interface","Title")
def main(argv=None):
 p=argparse.ArgumentParser(description=__doc__);p.add_argument("addon",type=Path);p.add_argument("--interface",type=int);p.add_argument("--toc",type=Path);p.add_argument("--text",action="store_true");a=p.parse_args(argv)
 root=a.addon.resolve(); findings=[]
 try:
  toc=a.toc if a.toc else None
  if toc is None:
   candidates=list(root.glob("*.toc"))
   if len(candidates)!=1: raise ValueError(f"expected one .toc, found {len(candidates)}; use --toc")
   toc=candidates[0]
  elif not toc.is_absolute(): toc=root/toc
  toc=toc.resolve()
  if root not in toc.parents or toc.suffix.lower()!=".toc": raise ValueError("TOC must be inside addon directory")
  meta={}; entries=[]
  for n,line in enumerate(read_text(toc).splitlines(),1):
   m=re.match(r"^\s*##\s*([^:]+)\s*:\s*(.*?)\s*$",line)
   if m: meta.setdefault(m.group(1).strip(),[]).append((m.group(2),n))
   elif line.strip() and not line.lstrip().startswith("#"): entries.append((line.strip(),n))
  for k in REQUIRED:
   if not meta.get(k) or not meta[k][0][0]: findings.append(finding("MissingMetadata",str(toc.relative_to(root)),"error",f"Missing {k} metadata"))
  interface=meta.get("Interface",[("",0)])[0][0]
  if interface and not re.fullmatch(r"\d{1,7}(?:\s*,\s*\d{1,7})*",interface): findings.append(finding("InvalidInterface","Interface","error","Interface must be numeric list"))
  if a.interface and str(a.interface) not in re.split(r"[\s,]+",interface): findings.append(finding("InterfaceMismatch","Interface","error",f"Requested {a.interface}, declared {interface}"))
  order=[]; active=set()
  for name,line in entries:
   if Path(name).is_absolute() or ".." in Path(name).parts: findings.append(finding("UnsafeLoadPath",str(toc.relative_to(root)),"error",f"Unsafe TOC entry: {name}"));continue
   target=(toc.parent/name).resolve()
   if root not in target.parents and target!=root: findings.append(finding("UnsafeLoadPath",name,"error","Entry escapes addon directory"))
   elif not target.is_file(): findings.append(finding("MissingLoadFile",name,"error","Listed file does not exist"))
   order.append({"path":name,"line":line})
  seen_xml=False
  for item in order:
   ext=Path(item["path"]).suffix.lower()
   if ext==".xml": seen_xml=True
   if ext==".lua" and seen_xml: findings.append(finding("LoadOrder","line:"+str(item["line"]),"warning","Lua appears after XML; verify intended load order"))
   if ext not in {".lua",".xml"}: findings.append(finding("UnexpectedLoadType",item["path"],"warning","TOC entry is not Lua or XML"))
  def inspect_xml(path,depth=0):
   rel=path.relative_to(root).as_posix()
   if depth>32:
    findings.append(finding("XmlDepthLimit",rel,"error","XML dependency nesting exceeds 32"));return
   if path in active:
    findings.append(finding("XmlIncludeCycle",rel,"error","XML include cycle detected"));return
   active.add(path)
   try:
    xml=read_text(path)
    if re.search(r'<!\s*(?:DOCTYPE|ENTITY)\b',xml,re.I):
     findings.append(finding("UnsafeXml",rel,"error","DTD/entity declarations are refused"));return
    doc=ET.fromstring(xml)
    for node in doc.iter():
     if node.tag.rsplit("}",1)[-1] not in {"Include","Script"} or "file" not in node.attrib: continue
     value=node.attrib["file"].replace("\\","/")
     if not value or value.startswith("/") or ":" in value or ".." in Path(value).parts:
      findings.append(finding("UnsafeXmlReference",rel,"error",f"Unsafe XML reference: {value}"));continue
     child=(path.parent/value).resolve()
     if root not in child.parents:
      findings.append(finding("UnsafeXmlReference",rel,"error",f"XML reference escapes addon directory: {value}"));continue
     if not child.is_file():
      findings.append(finding("MissingXmlDependency",value,"error",f"Included file not found from {rel}"));continue
     order.append({"path":child.relative_to(root).as_posix(),"source":rel})
     if child.suffix.lower()==".xml": inspect_xml(child,depth+1)
   except (OSError,ET.ParseError,ValueError) as e:
    findings.append(finding("InvalidXml",rel,"error",str(e)))
   finally: active.discard(path)
  for item in list(order):
   candidate=(root/item["path"]).resolve()
   if candidate.suffix.lower()==".xml" and candidate.is_file(): inspect_xml(candidate)
  return finish("TocManifestLinter",findings,a.text,metadata={k:v[0][0] for k,v in meta.items()},loadOrder=order,
   limitation="Does not execute Lua/XML or validate live client API behavior.")
 except (OSError,ValueError) as e:
  return finish("TocManifestLinter",[finding("InvalidAddon",str(root),"error",str(e))],a.text)
if __name__=="__main__":raise SystemExit(main())
