"""Validate versioned JSON state graphs and save payloads without executing them."""
from __future__ import annotations
import argparse,json
from pathlib import Path
from .common import emit,finding,finish,stderr_error

def main(argv=None):
 p=argparse.ArgumentParser(description=__doc__);p.add_argument("file",type=Path);p.add_argument("--expected-version",type=int);p.add_argument("--text",action="store_true");a=p.parse_args(argv)
 try:
  data=json.loads(a.file.read_text(encoding="utf-8-sig"))
  if not isinstance(data,dict): raise ValueError("top-level JSON must be an object")
  findings=[]; ver=data.get("schemaVersion",data.get("version"))
  if ver is None: findings.append(finding("UnversionedSchema",str(a.file),"warning","No version/schemaVersion field"))
  elif a.expected_version is not None and ver!=a.expected_version: findings.append(finding("SchemaVersionMismatch",str(a.file),"error",f"Expected version {a.expected_version}, found {ver}"))
  if "states" not in data or "transitions" not in data:
   findings.append(finding("InvalidSchema",str(a.file),"error","states and transitions arrays are required"))
  states=data.get("states",[]); transitions=data.get("transitions",[])
  if not isinstance(states,list) or not isinstance(transitions,list): raise ValueError("states and transitions must be arrays")
  state_ids=[]
  for i,s in enumerate(states):
   ident=s.get("id",s.get("name")) if isinstance(s,dict) else None
   if isinstance(ident,bool) or not isinstance(ident,(str,int)):
    findings.append(finding("InvalidState",f"states[{i}]","error","State must have a string or integer id/name"))
   else: state_ids.append(ident)
  names=set(state_ids)
  if len(names)!=len(states): findings.append(finding("InvalidState","states","error","State entries must have unique id/name values"))
  starts={s.get("id",s.get("name")) for s in states if isinstance(s,dict) and s.get("initial") is True and isinstance(s.get("id",s.get("name")),(str,int)) and not isinstance(s.get("id",s.get("name")),bool)}
  if len(starts)>1: findings.append(finding("MultipleInitialStates","states","error","More than one initial state"))
  referenced=set()
  for i,t in enumerate(transitions):
   if not isinstance(t,dict): findings.append(finding("InvalidTransition",f"transitions[{i}]","error","Transition must be an object"));continue
   src=t.get("from"); dst=t.get("to")
   if isinstance(src,bool) or not isinstance(src,(str,int)) or isinstance(dst,bool) or not isinstance(dst,(str,int)):
    findings.append(finding("InvalidTransition",f"transitions[{i}]","error","Transition endpoints must be string or integer ids"));continue
   referenced.update([src,dst])
   if src not in names or dst not in names: findings.append(finding("DanglingTransition",f"transitions[{i}]","error",f"Transition endpoint missing: {src!r} -> {dst!r}"))
  for n in sorted((names-referenced)-starts,key=str): findings.append(finding("OrphanState",str(n),"warning","State has no detected incoming or outgoing transition"))
  payload=finish("StateTimeMachineValidator",findings,a.text,version=ver,stateCount=len(states),transitionCount=len(transitions),initialStates=sorted(starts,key=str),
   limitation="Accepts JSON schema only; Godot Resource state-machine parsing is not performed.")
  return payload
 except (OSError,ValueError,json.JSONDecodeError) as e: return stderr_error(str(e))
if __name__=="__main__":raise SystemExit(main())
