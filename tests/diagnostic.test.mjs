import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const source=readFileSync(new URL('../diagnostics/webview2-win32/main.cpp',import.meta.url),'utf8');
const runner=readFileSync(new URL('../lab/octane-webview2-experiment',import.meta.url),'utf8');
const labCommand=readFileSync(new URL('../lab/octane-lab',import.meta.url),'utf8');
const controller=readFileSync(new URL('../scripts/Invoke-OctaneExperiment.ps1',import.meta.url),'utf8');

test('native diagnostic separates DOM activity from animation frames',()=>{
  assert.match(source,/requestAnimationFrame\(animate\)/);
  assert.match(source,/maxAnimationFrames|__octaneProbe/);
  assert.match(source,/dom-snapshot/);
  assert.match(source,/visible repaint unverified/);
});

test('native diagnostic supports controlled runtime selection and deadlines',()=>{
  assert.match(source,/OCTANE_WEBVIEW2_BROWSER_EXECUTABLE_FOLDER/);
  assert.match(source,/OCTANE_WEBVIEW2_BROWSER_ARGS/);
  assert.match(source,/CoreWebView2EnvironmentOptions/);
  assert.match(source,/stage-timeout/);
  assert.match(source,/ProcessFailed/);
  assert.match(source,/BrowserProcessExited/);
});

test('container probe captures native-window evidence without weakening sandbox defaults',()=>{
  assert.match(runner,/import -window/);
  assert.match(runner,/compare -metric AE/);
  assert.match(runner,/ffmpeg .*x11grab/);
  assert.match(runner,/xdotool .*windowminimize/);
  assert.match(runner,/wine-display-driver-maps/);
  assert.match(runner,/run_dir\/environment/);
  assert.doesNotMatch(runner,/--no-sandbox/);
  assert.doesNotMatch(runner,/--privileged/);
  assert.match(controller,/must not contain credentials or access tokens/);
  assert.match(controller,/profile\.json/);
  assert.match(controller,/Write-OctaneResultArtifacts/);
  assert.match(controller,/Update-OctaneEvidenceChecksums/);
});

test('Docker-Wine GUI commands verify the discovered xrdp display',()=>{
  assert.match(labCommand,/ensure_display\(\)/);
  assert.match(labCommand,/DISPLAY="\$candidate" XAUTHORITY="\$authority" xdpyinfo/);
  assert.match(labCommand,/No usable X11 display was found/);
  assert.match(labCommand,/install-silent\).*Octane-setup\.exe \/S/s);
});

test('pixel comparison survives Bash errexit when identify emits dimensions',()=>{
  assert.match(runner,/identify -format '%w %h\\n'/);
});
