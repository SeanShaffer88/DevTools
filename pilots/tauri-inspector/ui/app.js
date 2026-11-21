import {rowsFor,filterRows,acceptResult} from './model.mjs';
import {installCommandPalette} from './command-palette.mjs';
const $=id=>document.getElementById(id);
const invoke=(command,args)=>window.__TAURI__.core.invoke(command,args);
const PAGE_SIZE=100;
let request=0,busy=false,selecting=false,cancelled=false,rows=[],page=0;
function controls(){
 $('select').disabled=busy||selecting;
 $('inspect').disabled=busy||selecting||!$('path').value;
 $('cancel').disabled=!busy||cancelled;
}
function render(){
 const matches=filterRows(rows,$('search').value);
 const start=page*PAGE_SIZE;
 const visible=matches.slice(start,start+PAGE_SIZE);
 const paged=matches.length>PAGE_SIZE;
 $('pagination').hidden=!paged;
 $('previous-page').disabled=page===0;
 $('next-page').disabled=start+PAGE_SIZE>=matches.length;
 $('results').replaceChildren();
 for(const row of visible){
  const item=document.createElement('div');item.className='row';
  const kind=document.createElement('span');kind.className='kind';kind.textContent=row.kind;
  const value=document.createElement('span');value.textContent=row.value;
  item.append(kind,value);$('results').append(item);
 }
 $('count').textContent=paged
  ? (start+1).toLocaleString()+'–'+(start+visible.length).toLocaleString()+' of '+matches.length.toLocaleString()+' matches'
  : matches.length+' of '+rows.length+' evidence items';
 if(!visible.length){
  const message=document.createElement('p');message.className='empty';
  message.textContent=rows.length?'No matching evidence.':'No current evidence available.';
  $('results').append(message);
 }
}
function renderFirstPage(){
 page=0;
 render();
}
$('select').addEventListener('click',async()=>{
 if(selecting||busy)return;
 const focusOrigin=document.activeElement;
 selecting=true;
 controls();
 try{
  const folder=await invoke('select_folder');
  if(!folder)return;
  request++;
  $('path').value=folder;
  rows=[];
  renderFirstPage();
  $('status').textContent='Folder selected. Inspect to read project metadata.';
  $('stdout').textContent='Unavailable';
  $('stderr').textContent='Unavailable';
  $('meta').textContent='No inspection for this selection.';
 }catch(error){
  $('status').textContent=`Folder selection failed: ${error}`;
 }finally{
  selecting=false;
  controls();
  const active=document.activeElement;
  if((!active||active===document.body||active===document.documentElement||active===focusOrigin)
     && !$('select').disabled){
   $('select').focus();
  }
 }
});
$('inspect').addEventListener('click',async()=>{if(selecting||busy||!$('path').value)return;const id=++request;busy=true;cancelled=false;rows=[];renderFirstPage();controls();$('status').textContent='Inspecting… You can cancel this operation.';$('meta').textContent='Running';$('stdout').textContent='Pending';$('stderr').textContent='Pending';
 try{const result=await invoke('inspect',{path:$('path').value,requestId:id});
 if(result.requestId!==request)return;
 $('stdout').textContent=result.stdout||'(empty)';$('stderr').textContent=result.stderr||'(empty)';$('meta').textContent=`${result.status} · Exit ${result.exitCode??'unavailable'} · ${result.durationMs} ms · Request ${result.requestId}`;
 if(acceptResult(request,result.requestId,cancelled)){rows=result.report?rowsFor(result.report):[];renderFirstPage();$('status').textContent=result.message||result.status}
 else $('status').textContent='Cancelled. Result discarded; raw evidence is marked above.';
 }catch(error){$('status').textContent=`Inspection failed: ${error}`;$('meta').textContent='Host error; no accepted result.'}finally{busy=false;controls()}
});
$('cancel').addEventListener('click',async()=>{if(!busy||cancelled)return;cancelled=true;$('status').textContent='Cancelling…';$('cancel').disabled=true;try{await invoke('cancel',{requestId:request})}catch(error){$('status').textContent=`Cancellation failed: ${error}`}});
$('search').addEventListener('input',renderFirstPage);
$('previous-page').addEventListener('click',()=>{
 if($('previous-page').disabled)return;
 page--;
 render();
});
$('next-page').addEventListener('click',()=>{
 if($('next-page').disabled)return;
 page++;
 render();
});
$('theme').addEventListener('change',()=>{const value=$('theme').value;document.documentElement.dataset.theme=value});
if(!window.__TAURI__){$('select').disabled=true;$('status').textContent='Desktop host unavailable. Open the native application to inspect projects.'}
installCommandPalette(document);
