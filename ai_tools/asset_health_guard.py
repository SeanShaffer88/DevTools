"""Bounded static scan for Godot resource and asset health issues."""
from __future__ import annotations
import argparse, re
from pathlib import Path
from .common import walk_files, read_text, finding, finish, project_path

REF = re.compile(r'res://([^"\')\s]+)')
AUDIO = {".wav", ".ogg", ".mp3"}
IMAGE = {".png", ".jpg", ".jpeg", ".webp"}

def dimensions(path: Path):
    with path.open("rb") as stream: data=stream.read(2*1024*1024)
    if data.startswith(b"\x89PNG\r\n\x1a\n") and len(data)>=24:
        return int.from_bytes(data[16:20],"big"),int.from_bytes(data[20:24],"big")
    if data[:2]==b"BM" and len(data)>=26:
        return int.from_bytes(data[18:22],"little"),abs(int.from_bytes(data[22:26],"little",signed=True))
    if data[:3]==b"GIF" and len(data)>=10:
        return int.from_bytes(data[6:8],"little"),int.from_bytes(data[8:10],"little")
    if data[:4]==b"RIFF" and data[8:12]==b"WEBP" and data[12:16]==b"VP8X" and len(data)>=30:
        return int.from_bytes(data[24:27],"little")+1,int.from_bytes(data[27:30],"little")+1
    if data[:2]==b"\xff\xd8":
        i=2
        while i+4<len(data):
            if data[i]!=0xff: i+=1;continue
            marker=data[i+1];i+=2
            if marker in {0xd8,0xd9} or 0xd0<=marker<=0xd7: continue
            if i+2>len(data): break
            size=int.from_bytes(data[i:i+2],"big")
            if size<2 or i+size>len(data): break
            if marker in {0xc0,0xc1,0xc2,0xc3,0xc5,0xc6,0xc7,0xc9,0xca,0xcb,0xcd,0xce,0xcf} and size>=7:
                return int.from_bytes(data[i+5:i+7],"big"),int.from_bytes(data[i+3:i+5],"big")
            i+=size
    return None

def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__); p.add_argument("project",type=Path)
    p.add_argument("--max-texture-bytes",type=int,default=16*1024*1024)
    p.add_argument("--max-uncompressed-texture-bytes",type=int,default=256*1024*1024)
    p.add_argument("--max-files",type=int,default=20000); p.add_argument("--text",action="store_true")
    a=p.parse_args(argv); root=a.project.resolve(); findings=[]; referenced=set(); allfiles=walk_files(root,max_files=a.max_files)
    for f in allfiles:
        if f.suffix.lower() in {".tscn",".tres",".gd",".cs",".godot",".import"}:
            text=read_text(f)
            for m in REF.finditer(text):
                rel=m.group(1).split("::",1)[0]
                referenced.add(rel.replace("\\","/").casefold())
                if not project_path(root,"res://"+rel).exists():
                    findings.append(finding("MissingResource",str(f.relative_to(root)),"error",f"Missing res://{rel}"))
        if f.suffix.lower() in IMAGE and f.stat().st_size>a.max_texture_bytes:
            findings.append(finding("LargeTexture",str(f.relative_to(root)),"warning",
                                    "Compressed file exceeds configured size budget",bytes=f.stat().st_size,
                                    maxBytes=a.max_texture_bytes))
        if f.suffix.lower() in IMAGE:
            size=dimensions(f)
            if size:
                estimate=size[0]*size[1]*4
                if estimate>a.max_uncompressed_texture_bytes:
                    findings.append(finding("LargeDecodedTexture",str(f.relative_to(root)),"warning",
                        "Estimated RGBA decoded size exceeds configured budget",width=size[0],height=size[1],
                        estimatedBytes=estimate,maxBytes=a.max_uncompressed_texture_bytes))
        if f.suffix.lower() in {".tscn",".tres"}:
            text=read_text(f)
            if re.search(r'(?:StaticBody|CharacterBody|RigidBody|Area)[23]D',text) and not re.search(r'collision_(?:layer|mask)\s*=',text):
                findings.append(finding("CollisionDefaultsImplicit",str(f.relative_to(root)),"info",
                                        "Physics node found without explicit collision layer/mask; defaults may be intentional"))
    for f in allfiles:
        rel=f.relative_to(root).as_posix()
        if f.suffix.lower() in AUDIO and rel.casefold() not in referenced:
            findings.append(finding("UnreferencedAudio",rel,"info","No literal res:// reference found"))
    return finish("AssetHealthGuard",findings,a.text,filesScanned=len(allfiles),
                  limits={"maxFiles":a.max_files,"textureBytes":a.max_texture_bytes,
                          "uncompressedTextureBytes":a.max_uncompressed_texture_bytes},
                  note="Decoded texture size is a width×height×4 estimate; exact GPU/runtime memory varies.")
if __name__=="__main__": raise SystemExit(main())
