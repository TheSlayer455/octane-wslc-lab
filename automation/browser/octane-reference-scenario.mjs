import { chromium } from 'playwright';
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

function parseArguments(values) {
  const parsed = {};
  for (let index = 0; index < values.length; index += 2) {
    const key = values[index];
    if (!key?.startsWith('--') || index + 1 >= values.length) throw new Error(`Invalid argument at index ${index}`);
    parsed[key.slice(2)] = values[index + 1];
  }
  return parsed;
}

const options = parseArguments(process.argv.slice(2));
for (const required of ['url', 'password-file', 'output', 'run-id']) {
  if (!options[required]) throw new Error(`Missing --${required}`);
}
if (!/^https?:\/\/(127\.0\.0\.1|localhost):\d+\/octane\.html$/.test(options.url)) {
  throw new Error('The browser scenario accepts only an explicit localhost Octane viewer URL.');
}
if (!/^[a-f0-9]{10}$/.test(options['run-id'])) throw new Error('Invalid Octane run ID.');

const outputDirectory = path.resolve(options.output);
await mkdir(outputDirectory, { recursive: true });
const password = (await readFile(options['password-file'], 'utf8')).trim();
if (!password) throw new Error('Viewer credential file is empty.');

const result = {
  schemaVersion: 1,
  scenario: 'octane-reference-browser-v1',
  runId: options['run-id'],
  status: 'FAIL',
  client: { os: process.platform, automation: 'Playwright', playwright: '1.65.1', browser: null },
  viewport: { width: 1400, height: 900, deviceScaleFactor: 1 },
  startedAtUtc: new Date().toISOString(),
  forcedRepaintUsed: false,
  hiddenRetries: 0,
  manualOverrides: 0,
  actions: [],
  frames: [],
  screenshots: [],
  failure: null,
};

const browser = await chromium.launch({ headless: true });
result.client.browser = await browser.version();
const context = await browser.newContext({ viewport: result.viewport, deviceScaleFactor: 1 });
const page = await context.newPage();
page.setDefaultTimeout(30_000);

async function screenshot(name) {
  const file = path.join(outputDirectory, `${name}.png`);
  await page.screenshot({ path: file });
  const bytes = await readFile(file);
  result.screenshots.push({ file: path.basename(file), sha256: createHash('sha256').update(bytes).digest('hex'), length: bytes.length });
}

async function frameIdentity(label) {
  const value = await page.locator('#screen canvas').evaluate(async canvas => {
    const context2d = canvas.getContext('2d', { willReadFrequently: true });
    if (!context2d) throw new Error('noVNC canvas does not expose a 2D context');
    const pixels = context2d.getImageData(0, 0, canvas.width, canvas.height).data;
    const digest = await crypto.subtle.digest('SHA-256', pixels.buffer);
    const sha256 = Array.from(new Uint8Array(digest), item => item.toString(16).padStart(2, '0')).join('');
    const colors = new Set();
    const count = canvas.width * canvas.height;
    const stride = Math.max(1, Math.floor(count / 4096));
    for (let pixel = 0; pixel < count; pixel += stride) {
      const offset = pixel * 4;
      colors.add(`${pixels[offset]},${pixels[offset + 1]},${pixels[offset + 2]},${pixels[offset + 3]}`);
    }
    return { width: canvas.width, height: canvas.height, sampledUniqueColors: colors.size, rgbaSha256: sha256 };
  });
  const record = { label, observedAtUtc: new Date().toISOString(), ...value };
  result.frames.push(record);
  return record;
}

async function waitForFrameChange(beforeHash, label, timeoutMs = 20_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const current = await frameIdentity(label);
    if (current.rgbaSha256 !== beforeHash) return current;
    await page.waitForTimeout(200);
  }
  throw new Error(`Browser framebuffer did not change for ${label}`);
}

async function canvasPoint(remoteX, remoteY) {
  const box = await page.locator('#screen canvas').boundingBox();
  if (!box) throw new Error('noVNC canvas has no browser bounding box');
  return { x: box.x + (remoteX / 1280) * box.width, y: box.y + (remoteY / 800) * box.height };
}

async function remotePixel(remoteX, remoteY) {
  return page.locator('#screen canvas').evaluate((canvas, point) => {
    const context2d = canvas.getContext('2d', { willReadFrequently: true });
    const pixel = context2d.getImageData(point.x, point.y, 1, 1).data;
    return { red: pixel[0], green: pixel[1], blue: pixel[2], alpha: pixel[3] };
  }, { x: remoteX, y: remoteY });
}

async function waitForNativeDialog(visible, label, timeoutMs = 20_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    // The common Wine dialog owns this central client pixel and paints it
    // near-white. Octane's corresponding client point is deliberately dark.
    const pixel = await remotePixel(300, 300);
    const luminance = (pixel.red + pixel.green + pixel.blue) / 3;
    if ((visible && luminance > 180) || (!visible && luminance < 100)) {
      result.actions.push({ action: `${label}-${visible ? 'visible' : 'closed'}`, atUtc: new Date().toISOString(), observedLuminance: luminance });
      return;
    }
    await page.waitForTimeout(100);
  }
  throw new Error(`Native dialog did not become ${visible ? 'visible' : 'closed'} for ${label}`);
}

async function clickRemote(remoteX, remoteY, action) {
  const point = await canvasPoint(remoteX, remoteY);
  await page.mouse.click(point.x, point.y);
  result.actions.push({ action, atUtc: new Date().toISOString(), remoteX, remoteY });
}

async function typeRemote(text, action) {
  await page.keyboard.type(text, { delay: 4 });
  result.actions.push({ action, atUtc: new Date().toISOString(), characterCount: text.length });
}

try {
  await page.goto(options.url, { waitUntil: 'domcontentloaded' });
  await page.getByLabel('Per-run viewer password').fill(password);
  await page.getByRole('button', { name: 'Connect to this run' }).click();
  await page.locator('#state[data-state="vnc-negotiated"]').waitFor({ state: 'visible', timeout: 30_000 });
  result.actions.push({ action: 'vnc-negotiated', atUtc: new Date().toISOString() });
  const canvas = page.locator('#screen canvas');
  await canvas.waitFor({ state: 'visible' });

  let initial = null;
  const initialDeadline = Date.now() + 30_000;
  while (Date.now() < initialDeadline) {
    initial = await frameIdentity('initial-visible-poll');
    if (initial.width === 1280 && initial.height === 800 && initial.sampledUniqueColors > 100) break;
    await page.waitForTimeout(250);
  }
  if (!initial || initial.sampledUniqueColors <= 100) throw new Error('Browser canvas did not present a visually rich 1280x800 application frame.');
  await screenshot('01-initial-visible');

  let previous = initial.rgbaSha256;
  await clickRemote(232, 250, 'load-sample-set');
  let changed = await waitForFrameChange(previous, 'after-sample-workload');
  previous = changed.rgbaSha256;
  await screenshot('02-sample-workload');

  await clickRemote(96, 250, 'open-dialog-for-cancel');
  await waitForNativeDialog(true, 'open-cancel');
  changed = await frameIdentity('open-dialog-visible');
  previous = changed.rgbaSha256;
  await screenshot('03-open-dialog');
  await page.keyboard.press('Escape');
  result.actions.push({ action: 'cancel-open-dialog', atUtc: new Date().toISOString() });
  await waitForNativeDialog(false, 'open-cancel');
  changed = await frameIdentity('after-open-cancel');
  previous = changed.rgbaSha256;

  await clickRemote(96, 250, 'open-dialog-for-eight-file-selection');
  await waitForNativeDialog(true, 'open-eight-file');
  changed = await frameIdentity('open-dialog-reopened');
  previous = changed.rgbaSha256;
  await clickRemote(371, 503, 'focus-open-filename');
  const selection = [
    'LICENSE', 'config.json', 'data.csv', 'hello-copy.txt',
    'hello.txt', 'notes.txt', 'page.html', 'readme.md',
  ].map(name => `"C:\\octane-input\\selected\\${name}"`).join(' ');
  await typeRemote(selection, 'type-eight-file-selection');
  previous = (await frameIdentity('eight-file-selection-entered')).rgbaSha256;
  await page.keyboard.press('Enter');
  result.actions.push({ action: 'accept-eight-file-selection', atUtc: new Date().toISOString() });
  await waitForNativeDialog(false, 'open-eight-file', 30_000);
  changed = await waitForFrameChange(previous, 'after-eight-file-selection');
  previous = changed.rgbaSha256;
  await screenshot('04-eight-file-workload');

  await clickRemote(367, 250, 'save-dialog-for-cancel');
  await waitForNativeDialog(true, 'save-cancel');
  changed = await frameIdentity('save-dialog-visible');
  previous = changed.rgbaSha256;
  await screenshot('05-save-dialog');
  await page.keyboard.press('Escape');
  result.actions.push({ action: 'cancel-save-dialog', atUtc: new Date().toISOString() });
  await waitForNativeDialog(false, 'save-cancel');
  changed = await frameIdentity('after-save-cancel');
  previous = changed.rgbaSha256;

  await clickRemote(367, 250, 'save-dialog-for-export');
  await waitForNativeDialog(true, 'save-export');
  changed = await frameIdentity('save-dialog-reopened');
  previous = changed.rgbaSha256;
  await clickRemote(371, 503, 'focus-save-filename');
  await page.keyboard.press('Control+A');
  await typeRemote('C:\\octane-output\\browser-qualified-report.json', 'type-export-path');
  previous = (await frameIdentity('export-path-entered')).rgbaSha256;
  await page.keyboard.press('Enter');
  result.actions.push({ action: 'accept-save-dialog', atUtc: new Date().toISOString() });
  await waitForNativeDialog(false, 'save-export', 30_000);
  changed = await waitForFrameChange(previous, 'after-export');
  previous = changed.rgbaSha256;
  await screenshot('06-export-complete');

  await clickRemote(96, 250, 'post-export-responsiveness-open');
  await waitForNativeDialog(true, 'post-export-open');
  changed = await frameIdentity('post-export-dialog-visible');
  previous = changed.rgbaSha256;
  await page.keyboard.press('Escape');
  result.actions.push({ action: 'post-export-responsiveness-cancel', atUtc: new Date().toISOString() });
  await waitForNativeDialog(false, 'post-export-open');
  changed = await frameIdentity('post-export-responsive');
  previous = changed.rgbaSha256;

  const scrollPoint = await canvasPoint(820, 650);
  await page.mouse.move(scrollPoint.x, scrollPoint.y);
  await page.mouse.wheel(0, 560);
  result.actions.push({ action: 'browser-wheel-scroll', atUtc: new Date().toISOString() });
  changed = await waitForFrameChange(previous, 'after-browser-scroll');
  await screenshot('07-post-dialog-scroll');
  await page.waitForTimeout(1000);
  result.status = 'PASS';
} catch (error) {
  result.failure = error instanceof Error ? error.message : String(error);
  try { await screenshot('failure'); } catch {}
} finally {
  result.completedAtUtc = new Date().toISOString();
  await writeFile(path.join(outputDirectory, 'browser-scenario.json'), `${JSON.stringify(result, null, 2)}\n`, 'utf8');
  await context.close();
  await browser.close();
}

if (result.status !== 'PASS') {
  console.error(result.failure);
  process.exitCode = 1;
} else {
  console.log(JSON.stringify({ status: result.status, runId: result.runId, browser: result.client.browser }));
}
