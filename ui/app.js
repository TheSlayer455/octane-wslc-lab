import {formatBytes, summary} from './format.mjs';
const $ = id => document.getElementById(id);
let busy = false, hasReport = false;
function node(tag, text) { const e = document.createElement(tag); e.textContent = text; return e; }
function render(r) {
  ['files','groups','duplicates','bytes'].forEach((id,i) => $(id).textContent = summary(r)[i]);
  $('group-list').replaceChildren(...Object.entries(r.groups).map(([k,v]) => node('span', `${k} · ${v}`)));
  $('inventory').replaceChildren(...r.files.map(f => { const row = document.createElement('tr'); row.append(...[f.path,f.extension,formatBytes(f.bytes),f.sha256].map(t=>node('td',t))); return row; }));
  $('duplicate-list').replaceChildren(...r.duplicateSets.map((paths,i)=> { const group=node('div',`Set ${i+1}`); paths.forEach(p=>group.append(node('p',p))); return group; }));
  if (!r.duplicateSets.length) $('duplicate-list').textContent='No duplicate sets.';
  $('errors-section').hidden = !r.errors.length;
  $('errors').replaceChildren(...r.errors.map(e=>node('li',`${e.path}: ${e.error}`)));
  hasReport=true;
  $('status').textContent = `Analysis complete. ${r.files.length} files analyzed; ${r.errors.length} errors.`;
}
async function run(command) {
  if (busy) return;
  busy = true; ['choose','sample','export'].forEach(id=>$(id).disabled=true);
  $('status').textContent='Working…';
  try {
    if (!window.__TAURI__) throw new Error('Open the installed Octane application to use native file operations.');
    const result = await window.__TAURI__.core.invoke(command);
    if (command==='export_report') $('status').textContent=result ? `Report saved: ${result}` : 'Export canceled.';
    else if (result) render(result); else $('status').textContent='Selection canceled.';
  } catch(e) { $('status').textContent=`Error: ${String(e)}`; }
  finally { busy=false; ['choose','sample'].forEach(id=>$(id).disabled=false); $('export').disabled=!hasReport; }
}
$('choose').onclick=()=>run('choose_files'); $('sample').onclick=()=>run('load_sample'); $('export').onclick=()=>run('export_report');
