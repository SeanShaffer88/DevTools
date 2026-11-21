const gitProbeLabels = new Map([
 ['Available', 'Git work tree available'],
 ['NotAvailable', 'Git is unavailable'],
 ['NotRepository', 'Not a Git repository'],
 ['NotWorkTree', 'Not a Git work tree'],
 ['ProbeFailed', 'Git probe failed']
]);



export function rowsFor(report){
 const rows=[];
 for(const marker of report.markers) rows.push({kind:marker.kind,value:marker.path});
 for(const path of report.instructionFiles)rows.push({kind:'Instructions',value:path});
 for(const path of report.wrappers)rows.push({kind:'Wrapper',value:path});
 rows.push({kind:'Git branch',value:report.git?.branch??'Unavailable / Unknown (helper returned no Git evidence)'});
 if(report.git)rows.push({kind:'Git status',value:`${report.git.status}: ${report.git.statusReason}`});
 const probe=report.gitProbe;
 const label=gitProbeLabels.get(probe?.status);
 if(label){
  const value=probe.status==='ProbeFailed' && Number.isInteger(probe.exitCode)
   ? label+' (exit '+probe.exitCode+')'
   : label;
  rows.push({kind:'Git probe',value});
 }
 rows.push({kind:'Traversal',value:report.limitReached?'Entry limit reached — partial results':'Within the helper entry limit (depth 2 only)'});
 return rows;
}
export function filterRows(rows,query){const term=query.toLocaleLowerCase();return rows.filter(r=>`${r.kind} ${r.value}`.toLocaleLowerCase().includes(term))}
export function acceptResult(current,incoming,cancelled){return current===incoming&&!cancelled}
