export function installCommandPalette(doc) {
 const get=id=>doc.getElementById(id);
 const dialog=get('palette');
 if(!dialog)return;
 const opener=get('commands'),input=get('command-search'),list=get('command-results'),empty=get('command-empty');
 const actions=[
  ['Select Folder','select',element=>element.click()],
  ['Inspect','inspect',element=>element.click()],
  ['Cancel Inspection','cancel',element=>element.click()],
  ['Search Evidence','search',element=>element.focus()],
  ['Raw Evidence','raw',element=>{element.open=true;element.querySelector('summary').focus();}],
  ['Appearance','theme',element=>element.focus()],
  ['Previous Evidence Page','previous-page',element=>element.click()],
  ['Next Evidence Page','next-page',element=>element.click()]
 ];
 let origin, pending, matches=[],active=0;
 function renderActive() {
  for(let index=0;index<list.children.length;index++) {
   list.children[index].setAttribute('aria-selected',String(index===active));
  }
  const option=list.children[active];
  if(option){
   input.setAttribute('aria-activedescendant',option.id);
   option.scrollIntoView({block:'nearest'});
  }else input.removeAttribute('aria-activedescendant');
 }
 function render(){
  const query=input.value.trim().toLowerCase();
  matches=actions.filter(([label,id])=>{
   const control=get(id);
   return control && !control.disabled && !control.closest('[hidden]') && label.toLowerCase().includes(query);
  });
  active=0;
  list.replaceChildren();
  matches.forEach(([label],index)=>{
   const option=doc.createElement('li');
   option.id='command-option-'+index;
   option.setAttribute('role','option');
   option.textContent=label;
   option.addEventListener('pointerdown',event=>event.preventDefault());
   option.addEventListener('click',()=>run(index));
   list.append(option);
  });
  empty.hidden=matches.length>0;
  renderActive();
 }
 function run(index) {
  const action=matches[index];
  if(!action)return;
  const [,id,execute]=action;
  const control=get(id);
  if(!control || control.disabled || control.closest('[hidden]')){render();return;}
  pending=()=>execute(control);
  dialog.close();
 }
 function open(){
  if(dialog.open)return;
  origin=doc.activeElement;
  input.value='';
  dialog.showModal();
  input.setAttribute('aria-expanded','true');
  input.focus();
  render();
 }
 opener.addEventListener('click',open);
 get('close-palette').addEventListener('click',()=>dialog.close());
 dialog.addEventListener('close',()=>{
  input.setAttribute('aria-expanded','false');
  if(origin?.isConnected && !origin.disabled)origin.focus();
  else opener.focus();
  const execute=pending;
  pending=undefined;
  execute?.();
 });
 input.addEventListener('input',render);
 input.addEventListener('keydown',event=>{
  if(event.isComposing)return;
  if(event.key==='Enter'){event.preventDefault();run(active);}
  if(matches.length && (event.key==='ArrowDown'||event.key==='ArrowUp')){
   event.preventDefault();
   active=(active+(event.key==='ArrowDown'?1:-1)+matches.length)%matches.length;
   renderActive();
  }
 });
 doc.addEventListener('keydown',event=>{
  if((event.ctrlKey||event.metaKey)&&!event.altKey&&!event.shiftKey&&event.key.toLowerCase()==='k'){
   event.preventDefault();
   open();
  }
 });
}
