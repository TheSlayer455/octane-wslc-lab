import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const qualification=readFileSync(new URL('../lab/octane-qualification-experiment',import.meta.url),'utf8');
const dialogProbe=readFileSync(new URL('../diagnostics/win32-file-dialog/main.cpp',import.meta.url),'utf8');
const dialogRunner=readFileSync(new URL('../lab/octane-file-dialog-experiment',import.meta.url),'utf8');
const batch=readFileSync(new URL('../scripts/Invoke-OctaneQualificationBatch.ps1',import.meta.url),'utf8');
const aggregator=readFileSync(new URL('../scripts/Qualification.ps1',import.meta.url),'utf8');

test('strict qualification separates normal readiness from later window behavior',()=>{
  assert.match(qualification,/log_action pre-initial launch-installed-octane-once/);
  assert.match(qualification,/normal-window-activate-once/);
  assert.match(qualification,/wait_dialog_ready/);
  assert.match(qualification,/OCTANE_DIALOG_FOREGROUND_TIMEOUT_SECONDS/);
  assert.match(qualification,/xclip -selection clipboard -out/);
  assert.match(qualification,/write_gate pathEdgeCases PASS/);
  assert.match(qualification,/unicode-path-report\.json/);
  assert.match(qualification,/missing-input-report\.json/);
  assert.doesNotMatch(qualification,/xdotool type/);
  assert.match(qualification,/forcedRepaintUsed:\$forcedRepaintUsed/);
  assert.match(qualification,/acceptance-resize-to-900x650/);
  assert.match(qualification,/acceptance-minimize-once/);
  assert.match(qualification,/acceptance-restore-once/);
  assert.match(qualification,/hiddenRetries:0,manualOverrides:0/);
  assert.match(qualification,/primary_button_enabled/);
  assert.doesNotMatch(qualification,/for attempt in 1 2 3|trigger_attempt|Review-OctaneApplicationExperiment/);
});

test('file-dialog probe logging avoids the cross-thread lock inversion found during diagnosis',()=>{
  const foreground=dialogProbe.indexOf('const HWND foreground = GetForegroundWindow()');
  const lock=dialogProbe.indexOf('std::lock_guard<std::mutex> lock(g_log_mutex)',foreground);
  assert.ok(foreground>=0 && lock>foreground,'window state must be sampled before the log lock');
  assert.match(dialogRunner,/probeTimedOut/);
  assert.match(dialogRunner,/click_common_dialog_button/);
  assert.match(dialogRunner,/selectedPathsExact/);
  assert.match(dialogRunner,/xclip -selection clipboard -out/);
  assert.doesNotMatch(dialogRunner,/received Escape/);
});

test('batch declares ten runs before execution and requires exact cleanup and evidence',()=>{
  assert.match(batch,/\$plannedRunIds = 1\.\.10/);
  assert.match(batch,/Write-OctaneJsonAtomic.*batch\.json/);
  assert.match(batch,/rm','-f','-v',\$container/);
  assert.match(batch,/cleanupStatus='PASS'/);
  assert.match(batch,/requiredEvidence/);
  assert.match(batch,/Wait-QualificationPortAvailable/);
  assert.match(batch,/interRunPortAvailabilityTimeoutSeconds/);
  assert.match(batch,/output\/unicode-path-report\.json/);
  assert.match(batch,/output\/missing-input-report\.json/);
  assert.match(batch,/127\.0\.0\.1:\$\{Port\}:3389/);
  assert.doesNotMatch(batch,/--privileged|--network[= ]host|docker\.sock|--device/);
  assert.doesNotMatch(batch,/Podman|podman/);
});

test('batch aggregation cannot promote partial or manually overridden results',()=>{
  assert.match(aggregator,/ExpectedRunCount = 10/);
  assert.match(aggregator,/manual overrides/);
  assert.match(aggregator,/hidden retries/);
  assert.match(aggregator,/used forced repainting/);
  assert.match(aggregator,/cleanup did not pass/);
  assert.match(aggregator,/evidence validation did not pass/);
});
