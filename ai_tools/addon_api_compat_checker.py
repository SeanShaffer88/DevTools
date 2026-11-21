"""Flag a small, documented advisory catalog of obsolete WoW Lua APIs."""
from __future__ import annotations
import argparse,re
from pathlib import Path
from .common import walk_files,read_text,finding,finish

# Advisory names only; update this list against a user-supplied, versioned source before release decisions.
DEPRECATED={
 "GetSpellInfo":"API changed in modern clients; use the matching C_Spell API/profile.",
 "GetSpellCooldown":"API shape changed in modern clients; verify C_Spell.GetSpellCooldown.",
 "UnitBuff":"Aura API changed; verify C_UnitAuras and return-value shape.",
 "UnitDebuff":"Aura API changed; verify C_UnitAuras and return-value shape.",
 "GetContainerItemInfo":"Container API changed; verify C_Container.GetContainerItemInfo.",
 "GetNumGroupMembers":"Verify against the selected client API; legacy raid/group aliases vary.",
}
def main(argv=None):
 p=argparse.ArgumentParser(description=__doc__);p.add_argument("addon",type=Path);p.add_argument("--interface",type=int,required=True);p.add_argument("--text",action="store_true");a=p.parse_args(argv)
 findings=[]; refs=[]
 for f in walk_files(a.addon.resolve(),{".lua"}):
  text=read_text(f); rel=f.relative_to(a.addon.resolve()).as_posix()
  for name,why in DEPRECATED.items():
   for m in re.finditer(r'\b'+re.escape(name)+r'\b',text):
    findings.append(finding("PossibleDeprecatedAPI",rel,"warning",why,line=text.count("\n",0,m.start())+1,symbol=name))
    refs.append(name)
 return finish("AddonApiCompatChecker",findings,a.text,targetInterface=a.interface,advisoryCatalogVersion="embedded-1",
  matchedSymbols=sorted(set(refs)),limitation="Curated heuristic list, not authoritative for any client build; inspect current API documentation before changing code.")
if __name__=="__main__":raise SystemExit(main())
