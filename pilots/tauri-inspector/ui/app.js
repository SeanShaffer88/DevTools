import {rowsFor,filterRows,acceptResult} from './model.mjs';
const $=id=>document.getElementById(id);
const invoke=(command,args)=>window.__TAURI__.core.invoke(command,args);
let request=0,busy=false,cancelled=false,rows=[];
function controls(){ $('select').disabled=busy;$('inspect').disabled=busy||!$('path').value;$('cancel').disabled=!busy; }
function render(){const visible=filterRows(rows,$('search').value);$('results').replaceChildren();
 for(const row of visible){const item=document.createElement('div');item.className='row';const kind=document.createElement('span');kind.className='kind';kind.textContent=row.kind;const value=document.createElement('span');value.textContent=row.value;item.append(kind,value);$('results').append(item)}
 $('count').textContent=`${visible.length} of ${rows.length} evidence items`;
 if(!visible.length){const p=document.createElement('p');p.className='empty';p.textContent=rows.length?'No matching evidence.':'No current evidence available.';$('results').append(p)}
}
$('select').addEventListener('click',async()=>{try{const folder=await invoke('select_folder');if(folder){request++;$('path').value=folder;rows=[];render();$('status').textContent='Folder selected. Inspect to read project metadata.';$('stdout').textContent='Unavailable';$('stderr').textContent='Unavailable';$('meta').textContent='No inspection for this selection.';controls()}}catch(error){$('status').textContent=`Folder selection failed: ${error}`}});
$('inspect').addEventListener('click',async()=>{const id=++request;busy=true;cancelled=false;rows=[];render();controls();$('status').textContent='Inspecting… You can cancel this operation.';$('meta').textContent='Running';$('stdout').textContent='Pending';$('stderr').textContent='Pending';
 try{const result=await invoke('inspect',{path:$('path').value,requestId:id});
 if(result.requestId!==request)return;
 $('stdout').textContent=result.stdout||'(empty)';$('stderr').textContent=result.stderr||'(empty)';$('meta').textContent=`${result.status} · Exit ${result.exitCode??'unavailable'} · ${result.durationMs} ms · Request ${result.requestId}`;
 if(acceptResult(request,result.requestId,cancelled)){rows=result.report?rowsFor(result.report):[];render();$('status').textContent=result.message||result.status}
 else $('status').textContent='Cancelled. Result discarded; raw evidence is marked above.';
 }catch(error){$('status').textContent=`Inspection failed: ${error}`;$('meta').textContent='Host error; no accepted result.'}finally{busy=false;controls()}
});
$('cancel').addEventListener('click',async()=>{cancelled=true;$('status').textContent='Cancelling…';$('cancel').disabled=true;try{await invoke('cancel',{requestId:request})}catch(error){$('status').textContent=`Cancellation failed: ${error}`}});
$('search').addEventListener('input',render);
$('theme').addEventListener('change',()=>{const value=$('theme').value;if(value==='system')delete document.documentElement.dataset.theme;else document.documentElement.dataset.theme=value});
if(!window.__TAURI__){$('select').disabled=true;$('status').textContent='Desktop host unavailable. Open the native application to inspect projects.'}
