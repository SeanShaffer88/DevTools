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
