import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {summary,formatBytes} from '../ui/format.mjs';
function setup(invoke) {
  const nodes = new Map();
  function element() {return {textContent:'',disabled:false,hidden:false,children:[],append(...c){this.children.push(...c)},replaceChildren(...c){this.children=c}}}
  const document={getElementById(id){if(!nodes.has(id))nodes.set(id,element());return nodes.get(id)},createElement:element};
  const source=readFileSync(new URL('../ui/app.js',import.meta.url),'utf8').replace(/^import[^\n]+\n/,'');
  vm.runInNewContext(source,{document,window:{__TAURI__:{core:{invoke}}},summary,formatBytes});
  return id=>document.getElementById(id);
}
const report={files:[{path:'<img src=x onerror=alert(1)>',extension:'txt',bytes:5,sha256:'abc'}],groups:{txt:1},duplicateSets:[],totalBytes:5,errors:[]};
test('native report renders file paths as literal text and enables export',async()=>{
  const $=setup(async command=>{assert.equal(command,'load_sample');return report});
  await $('sample').onclick(); assert.equal($('files').textContent,1);assert.equal($('export').disabled,false);
  assert.equal($('inventory').children[0].children[0].textContent,report.files[0].path);
});
test('canceling a picker preserves previous report',async()=>{
  const $=setup(async command=>command==='load_sample'?report:null);
  await $('sample').onclick();await $('choose').onclick();
  assert.equal($('files').textContent,1); assert.equal($('status').textContent,'Selection canceled.');
});
test('native failures are visible and controls recover',async()=>{
  const $=setup(async()=>{throw Error('permission denied')}); await $('sample').onclick();
  assert.match($('status').textContent,/permission denied/);assert.equal($('sample').disabled,false);assert.equal($('export').disabled,true);
});
test('export cancellation and success are distinct',async()=>{
  let result=null; const $=setup(async command=>command==='load_sample'?report:result);
  await $('sample').onclick();await $('export').onclick();assert.equal($('status').textContent,'Export canceled.');
  result='Z:\\config\\octane-evidence\\report.json';await $('export').onclick();assert.match($('status').textContent,/Report saved:/);
});
