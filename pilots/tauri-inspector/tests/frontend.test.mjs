import {test} from 'node:test';
import assert from 'node:assert/strict';
import {rowsFor,filterRows,acceptResult} from '../ui/model.mjs';
test('unknown Git remains explicit and filtering treats filenames as text',()=>{
 const rows=rowsFor({markers:[{kind:'Rust',path:'space ü/<script>.toml'}],instructionFiles:['README.md'],wrappers:[],git:null,limitReached:false});
 assert.equal(filterRows(rows,'Ü/<script>')[0].value,'space ü/<script>.toml');
 assert.ok(rows.some(r=>r.value.includes('Unavailable / Unknown')));
});
test('late and cancelled requests cannot replace current results',()=>{
 assert.equal(acceptResult(4,3,false),false);assert.equal(acceptResult(4,4,true),false);assert.equal(acceptResult(4,4,false),true);
});
test('recognized Git probe outcomes render a friendly row',()=>{
 const report={markers:[],instructionFiles:[],wrappers:[],git:null};
 for(const [status,exitCode,value] of [
  ['Available',0,'Git work tree available'],
  ['NotAvailable',null,'Git is unavailable'],
  ['NotRepository',128,'Not a Git repository'],
  ['NotWorkTree',0,'Not a Git work tree'],
  ['ProbeFailed',128,'Git probe failed (exit 128)']
 ]){
  assert.deepEqual(rowsFor({...report,gitProbe:{status,exitCode}}).find(row=>row.kind==='Git probe'),{kind:'Git probe',value});
 }
});
test('legacy or malformed Git probe data leaves legacy rows intact',()=>{
 const report={markers:[],instructionFiles:[],wrappers:[],git:{branch:'main',status:'Unknown',statusReason:'Not checked'}};
 const legacy=rowsFor(report);
 assert.deepEqual(legacy.slice(0,2),[{kind:'Git branch',value:'main'},{kind:'Git status',value:'Unknown: Not checked'}]);
 for(const gitProbe of [null,{},'Available',[],{status:'FutureStatus',exitCode:128},{status:'constructor'}]){
  assert.deepEqual(rowsFor({...report,gitProbe}),legacy);
 }
 assert.deepEqual(rowsFor({...report,gitProbe:{status:'ProbeFailed',exitCode:'128'}}).find(row=>row.kind==='Git probe'),{kind:'Git probe',value:'Git probe failed'});
});

async function loadApp(t,name,invoke){
 const elements=new Map();
 function element(){
  return {value:'',textContent:'',disabled:false,children:[],events:{},
   addEventListener(type,handler){this.events[type]=handler;},
   focus(){assert.equal(this.disabled,false);document.activeElement=this;},
   replaceChildren(){this.children=[];},
   append(...children){this.children.push(...children);}};
 }
 for(const id of ['select','inspect','cancel','path','search','status','meta','stdout','stderr','results','count','theme','pagination','previous-page','next-page']){
  elements.set(id,element());
 }
 const originalDocument=globalThis.document,originalWindow=globalThis.window;
 t.after(()=>{
  if(originalDocument===undefined)delete globalThis.document;else globalThis.document=originalDocument;
  if(originalWindow===undefined)delete globalThis.window;else globalThis.window=originalWindow;
 });
 globalThis.document={getElementById:id=>elements.get(id),createElement:element,body:element()};
 globalThis.window={__TAURI__:{core:{invoke}}};
 const app=new URL('../ui/app.js',import.meta.url);
 app.searchParams.set('test',name);
 await import(app.href);
 return elements;
}

test('folder picker blocks competing actions and preserves results on dismiss or error',async t=>{
 const calls=[];
 let picker;
 const elements=await loadApp(t,'picker',(command,args)=>{
  calls.push(command);
  if(command==='select_folder'){
   picker=Promise.withResolvers();
   return picker.promise;
  }
  if(command==='inspect'){
   return Promise.resolve({requestId:args.requestId,status:'completed',stdout:'prior evidence',
    report:{markers:[],instructionFiles:[],wrappers:[],git:null}});
  }
 });
 const select=elements.get('select'),inspect=elements.get('inspect'),cancel=elements.get('cancel');
 const path=elements.get('path'),stdout=elements.get('stdout'),meta=elements.get('meta'),results=elements.get('results');
 path.value='C:\\old';
 await inspect.events.click();
 const oldRows=results.children;
 const oldMeta=meta.textContent;
 const origin={};
 document.activeElement=origin;
 const dismiss=select.events.click();
 assert.equal(select.disabled,true);
 assert.equal(inspect.disabled,true);
 assert.equal(cancel.disabled,true);
 await select.events.click();
 await inspect.events.click();
 await cancel.events.click();
 assert.deepEqual(calls,['inspect','select_folder']);
 picker.resolve(null);
 await dismiss;
 assert.equal(document.activeElement,select);
 assert.equal(path.value,'C:\\old');
 assert.equal(stdout.textContent,'prior evidence');
 assert.equal(meta.textContent,oldMeta);
 assert.equal(results.children,oldRows);
 assert.equal(select.disabled,false);
 assert.equal(inspect.disabled,false);

 const failure=select.events.click();
 elements.get('search').focus();
 picker.reject(new Error('picker unavailable'));
 await failure;
 assert.equal(document.activeElement,elements.get('search'));
 assert.match(elements.get('status').textContent,/Folder selection failed: .*picker unavailable/);
 assert.equal(select.disabled,false);
 assert.equal(inspect.disabled,false);
 assert.equal(results.children,oldRows);
 assert.equal(path.value,'C:\\old');

 const chosen=select.events.click();
 document.activeElement=document.body;
 picker.resolve('C:\\new');
 await chosen;
 assert.equal(document.activeElement,select);
 assert.equal(path.value,'C:\\new');
 assert.equal(stdout.textContent,'Unavailable');
 assert.equal(meta.textContent,'No inspection for this selection.');
 assert.notEqual(results.children,oldRows);
 assert.equal(select.disabled,false);
 assert.equal(inspect.disabled,false);
 assert.equal(cancel.disabled,true);
});

test('result pages stay bounded while search reaches all evidence',async t=>{
 const markers=Array.from({length:205},(_,index)=>({kind:'Fixture',path:'evidence-'+String(index).padStart(3,'0')}));
 const elements=await loadApp(t,'paging',(command,args)=>{
  if(command==='select_folder')return Promise.resolve('C:\\next');
  return Promise.resolve({requestId:args.requestId,status:'completed',stdout:'complete evidence',
   report:{markers,instructionFiles:[],wrappers:[],git:null}});
 });
 const path=elements.get('path'),inspect=elements.get('inspect'),search=elements.get('search');
 const results=elements.get('results'),count=elements.get('count'),pagination=elements.get('pagination');
 const previous=elements.get('previous-page'),next=elements.get('next-page');
 const values=()=>results.children.map(row=>row.children[1]?.textContent);
 path.value='C:\\fixture';
 await inspect.events.click();
 assert.equal(results.children.length,100);
 assert.match(count.textContent,/^1–100 of 207 matches$/);
 assert.equal(pagination.hidden,false);
 assert.equal(previous.disabled,true);
 assert.equal(next.disabled,false);
 previous.events.click();
 assert.equal(values()[0],'evidence-000');
 next.events.click();
 assert.equal(values()[0],'evidence-100');
 next.events.click();
 assert.equal(values()[0],'evidence-200');
 assert.equal(results.children.length,7);
 assert.equal(next.disabled,true);
 next.events.click();
 assert.equal(values()[0],'evidence-200');
 assert.match(count.textContent,/^201–207 of 207 matches$/);
 assert.equal(elements.get('stdout').textContent,'complete evidence');

 search.value='evidence-004'; search.events.input();
 assert.deepEqual(values(),['evidence-004']);
 assert.equal(pagination.hidden,true);
 search.value='missing'; search.events.input();
 assert.equal(results.children[0].textContent,'No matching evidence.');
 assert.equal(pagination.hidden,true);
 search.value=''; search.events.input();
 assert.equal(values()[0],'evidence-000');
 next.events.click();
 await inspect.events.click();
 assert.equal(values()[0],'evidence-000');
 next.events.click();
 await elements.get('select').events.click();
 assert.equal(results.children[0].textContent,'No current evidence available.');
 assert.equal(pagination.hidden,true);
});
