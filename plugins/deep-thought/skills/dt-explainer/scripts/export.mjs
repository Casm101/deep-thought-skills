#!/usr/bin/env node
// Frame-exact export for an animated explainer built from assets/template.html.
// It steps the page's timeline with window.explainer.seek(t) and screenshots every frame,
// so the output never drops frames and the resolution is set by --width/--height/--scale.
//
//   node export.mjs <explainer.html> --stills [dir]       one PNG per scene (no ffmpeg needed)
//   node export.mjs <explainer.html> [--out file.mp4]     MP4 via ffmpeg (H.264 + AAC when audio is on)
//
// Options: --fps 30  --width 1920  --height 1080  --scale 1  --theme light|dark  --no-audio

import { execSync, spawn } from 'node:child_process';
import { createRequire } from 'node:module';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync, existsSync } from 'node:fs';
import { basename, dirname, extname, join, resolve } from 'node:path';
import { homedir, tmpdir } from 'node:os';
import { pathToFileURL } from 'node:url';

function parseArgs(argv) {
  const o = { fps: 30, width: 1920, height: 1080, scale: 1, theme: 'dark', audio: true, stills: null, out: null, file: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const next = () => argv[++i];
    if (a === '--fps') o.fps = Number(next());
    else if (a === '--width') o.width = Number(next());
    else if (a === '--height') o.height = Number(next());
    else if (a === '--scale') o.scale = Number(next());
    else if (a === '--theme') o.theme = next();
    else if (a === '--no-audio') o.audio = false;
    else if (a === '--out') o.out = next();
    else if (a === '--stills') o.stills = argv[i + 1] && !argv[i + 1].startsWith('--') ? next() : '';
    else if (!o.file) o.file = a;
  }
  if (!o.file) {
    console.error('usage: node export.mjs <explainer.html> [--stills [dir]] [--out file.mp4] [--fps 30] [--width 1920] [--height 1080] [--scale 1] [--theme light|dark] [--no-audio]');
    process.exit(1);
  }
  return o;
}

function has(cmd) {
  try { execSync(`command -v ${cmd}`, { stdio: 'ignore', shell: '/bin/sh' }); return true; } catch { return false; }
}

function loadChromium() {
  const require = createRequire(import.meta.url);
  const candidates = ['playwright', 'playwright-core'];
  // dt-browser-run keeps a playwright-core here, installed once against the chromium
  // already in ~/Library/Caches/ms-playwright. Looking here first means this skill
  // needs no global install of its own, and the family shares one copy.
  const dtCache = join(process.env.DT_PLAYWRIGHT_HOME || join(homedir(), '.cache', 'dt-browser-run'),
                       'node_modules', 'playwright-core');
  if (existsSync(dtCache)) candidates.unshift(dtCache);
  try {
    const g = execSync('npm root -g', { encoding: 'utf8' }).trim();
    candidates.push(
      join(g, 'playwright'),
      join(g, 'playwright-core'),
      join(g, '@playwright/cli/node_modules/playwright'),
      join(g, '@playwright/cli/node_modules/playwright-core'),
    );
  } catch {}
  for (const c of candidates) {
    try { return require(c).chromium; } catch {}
  }
  console.error('Playwright not found. The dt way is to let dt-browser-run install it once:\n' +
                '  plugins/deep-thought/skills/dt-browser-run/scripts/browser-run.sh <any plan>\n' +
                'or install a global copy: npm i -g playwright && npx playwright install chromium');
  process.exit(2);
}

const opt = parseArgs(process.argv.slice(2));
const file = resolve(opt.file);
if (!existsSync(file)) { console.error(`not found: ${file}`); process.exit(1); }
const stem = join(dirname(file), basename(file, extname(file)));

if (opt.stills === null && !has('ffmpeg')) {
  console.error('ffmpeg not found. Install it (brew install ffmpeg), or run with --stills for PNGs only.');
  process.exit(2);
}

const chromium = loadChromium();
// Prefer Playwright's own Chromium; fall back to installed Chrome when its build is missing.
async function launch() {
  try { return await chromium.launch(); } catch (first) {
    try { return await chromium.launch({ channel: 'chrome' }); } catch {
      console.error(`${first.message.split('\n')[0]}\nRun: npx playwright install chromium (or install Google Chrome).`);
      process.exit(2);
    }
  }
}
const browser = await launch();
const page = await browser.newPage({ viewport: { width: opt.width, height: opt.height }, deviceScaleFactor: opt.scale });
const errors = [];
page.on('pageerror', e => errors.push(e.message));
page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });

const url = `${pathToFileURL(file).href}?export=1&theme=${encodeURIComponent(opt.theme)}`;
await page.goto(url);
await page.waitForFunction(() => window.explainer);
await page.evaluate(() => window.explainer.ready);
const info = await page.evaluate(() => ({ duration: window.explainer.duration, hasAudio: window.explainer.hasAudio, scenes: window.explainer.scenes }));

async function shot(t) {
  await page.evaluate(x => window.explainer.seek(x), t);
  return page.screenshot({ type: 'png' });
}

function finish(code) {
  if (errors.length) {
    console.error(`\npage errors (${errors.length}):\n  ${[...new Set(errors)].join('\n  ')}`);
    code ||= 3;
  }
  return browser.close().then(() => process.exit(code));
}

if (opt.stills !== null) {
  const dir = resolve(opt.stills || `${stem}-stills`);
  mkdirSync(dir, { recursive: true });
  for (const [i, s] of info.scenes.entries()) {
    // 75% through each scene: most elements are on screen, the fade-out has not started.
    const path = join(dir, `${String(i + 1).padStart(2, '0')}-${s.id}.png`);
    writeFileSync(path, await shot(s.start + s.dur * 0.75));
    console.log(path);
  }
  console.log(`duration ${info.duration.toFixed(1)}s, ${info.scenes.length} scenes`);
  await finish(0);
}

const out = resolve(opt.out || `${stem}.mp4`);
const tmp = mkdtempSync(join(tmpdir(), 'explainer-'));
let wav = null;
if (info.hasAudio && opt.audio) {
  const b64 = await page.evaluate(() => window.explainer.renderWav());
  wav = join(tmp, 'audio.wav');
  writeFileSync(wav, Buffer.from(b64, 'base64'));
}

const args = [
  '-y', '-loglevel', 'error',
  '-f', 'image2pipe', '-framerate', String(opt.fps), '-c:v', 'png', '-i', '-',
  ...(wav ? ['-i', wav] : []),
  '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '18', '-preset', 'medium',
  ...(wav ? ['-c:a', 'aac', '-b:a', '192k', '-shortest'] : []),
  '-movflags', '+faststart', out,
];
const ff = spawn('ffmpeg', args, { stdio: ['pipe', 'inherit', 'inherit'] });
const ffDone = new Promise(res => ff.on('close', res));
const write = buf => new Promise((res, rej) => ff.stdin.write(buf, err => (err ? rej(err) : res())));

const total = Math.round(info.duration * opt.fps);
for (let i = 0; i <= total; i++) {
  await write(await shot(Math.min(info.duration, i / opt.fps)));
  if (i % opt.fps === 0 || i === total) process.stderr.write(`\rframe ${i}/${total}`);
}
ff.stdin.end();
const code = await ffDone;
rmSync(tmp, { recursive: true, force: true });
if (code !== 0) { console.error(`\nffmpeg exited with ${code}`); await finish(4); }
console.log(`\n${out} (${info.duration.toFixed(1)}s, ${opt.width * opt.scale}x${opt.height * opt.scale}, ${opt.fps} fps${wav ? ', with audio' : ''})`);
await finish(0);
