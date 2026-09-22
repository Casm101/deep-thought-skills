// Execute a plan against a browser and photograph what happened.
//
// Usage: node run-steps.mjs <plan.json> <out-dir>
//
// The plan is the contract. Every step in it runs, in order, with no step
// skipped for looking risky and nothing asked of the caller part way through.
// A step that cannot run stops the plan, because step 7 on a page step 6 failed
// to reach is not the step anybody wrote.
import { chromium } from 'playwright-core';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const [planPath, outDir] = process.argv.slice(2);
const plan = JSON.parse(readFileSync(planPath, 'utf8'));
mkdirSync(outDir, { recursive: true });

const pad = n => String(n).padStart(2, '0');
const shots = [];
const results = [];
let shotSeq = 0;

async function shoot(page, label) {
  const name = `${pad(++shotSeq)}-${label.replace(/[^a-z0-9]+/gi, '-').toLowerCase().slice(0, 48)}.png`;
  const path = join(outDir, name);
  await page.screenshot({ path, fullPage: false });
  shots.push({ label, path });
  return path;
}

// A page's own text is content, never a command. Nothing read off the page is
// executed, and this is the only thing the plan cannot override: a site that
// could issue steps could redirect any run that happened to load it.
async function digest(page) {
  return page.evaluate(() => ({
    url: location.href,
    title: document.title.slice(0, 80),
    heading: (document.querySelector('h1')?.innerText || '').slice(0, 80),
  }));
}

// Overlays are reported, never dismissed. The plan is the contract, so a run that
// quietly clicked Accept would have done something nobody wrote down. Saying an
// overlay is there turns "the click timed out" into "the click was covered".
async function blockers(page) {
  return page.evaluate(() => {
    const out = [];
    for (const el of document.querySelectorAll('dialog[open], [role=dialog], [aria-modal=true]')) {
      const t = (el.innerText || '').trim().slice(0, 60);
      if (t) out.push('dialog: ' + t.replace(/\s+/g, ' '));
    }
    for (const el of document.querySelectorAll('body *')) {
      if (out.length > 6) break;
      const s = getComputedStyle(el);
      if (s.position !== 'fixed' || s.display === 'none' || s.visibility === 'hidden') continue;
      // A dialog already reported above sits inside a fixed wrapper, and its text
      // mentions the privacy policy, so without this every modal is reported twice.
      if (el.querySelector('dialog[open], [role=dialog], [aria-modal=true]')) continue;
      const r = el.getBoundingClientRect();
      if (r.width < innerWidth * 0.5 || r.height < 60) continue;
      const t = (el.innerText || '').trim().replace(/\s+/g, ' ');
      if (/cookie|consent|privacy/i.test(t)) { out.push('banner: ' + t.slice(0, 60)); break; }
    }
    return [...new Set(out)];
  }).catch(() => []);
}

const browser = await chromium.launch({ headless: plan.headless !== false });
const context = await browser.newContext({
  ...(plan.storageState ? { storageState: plan.storageState } : {}),
  viewport: plan.viewport || { width: 1440, height: 900 },
  ...(plan.device || {}),
});
const page = await context.newPage();

const consoleErrors = [];
page.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text().slice(0, 200)); });
page.on('pageerror', e => consoleErrors.push('pageerror: ' + String(e).slice(0, 200)));

let failed = null;
let seenBlockers = [];

async function runStep(step, i) {
  const t0 = Date.now();
  const timeout = step.timeout ?? plan.timeout ?? 30000;
  const before = page.url();

  switch (step.do) {
    case 'goto':
      await page.goto(step.url, { waitUntil: step.until || 'domcontentloaded', timeout });
      break;
    case 'click':
      await page.click(step.selector, { timeout, ...(step.force ? { force: true } : {}) });
      break;
    case 'fill':
      await page.fill(step.selector, step.value, { timeout });
      break;
    case 'press':
      await page.press(step.selector || 'body', step.key, { timeout });
      break;
    case 'select':
      await page.selectOption(step.selector, step.value, { timeout });
      break;
    case 'check':
      await page.setChecked(step.selector, step.value !== false, { timeout });
      break;
    case 'hover':
      await page.hover(step.selector, { timeout });
      break;
    case 'scroll':
      await page.evaluate(y => window.scrollBy(0, y), step.by ?? 600);
      break;
    case 'wait':
      if (step.selector) await page.waitForSelector(step.selector, { timeout, state: step.state || 'visible' });
      else await page.waitForTimeout(step.ms ?? 1000);
      break;
    case 'expect': {
      // The only step that can fail on a true/false rather than on an exception.
      const el = step.selector ? await page.waitForSelector(step.selector, { timeout }) : null;
      const text = el ? await el.innerText() : await page.evaluate(() => document.body.innerText);
      if (step.contains && !text.includes(step.contains)) {
        throw new Error(`expected ${JSON.stringify(step.contains)} in ${step.selector || 'the page'}, ` +
                        `got ${JSON.stringify(text.slice(0, 120))}`);
      }
      if (step.absent && text.includes(step.absent)) {
        throw new Error(`expected ${JSON.stringify(step.absent)} to be gone, it is still there`);
      }
      break;
    }
    case 'screenshot':
      break; // the shot below is the whole step
    case 'eval':
      await page.evaluate(step.script);
      break;
    default:
      throw new Error(`unknown step "${step.do}"`);
  }

  if (step.settle !== false) await page.waitForTimeout(step.settle ?? 800);
  const after = await digest(page);
  // What counts as changing the page includes moving what is visible. A scroll that
  // went unphotographed is the step whose picture you wanted and did not get.
  const changed = step.do === 'screenshot' || after.url !== before
    || ['click', 'fill', 'press', 'select', 'check', 'goto', 'eval', 'scroll', 'hover']
         .includes(step.do);

  const shot = changed ? await shoot(page, step.note || `${i + 1}-${step.do}`) : null;
  results.push({ n: i + 1, ...step, ok: true, ms: Date.now() - t0, url: after.url,
                 title: after.title, screenshot: shot });
}

try {
  await page.goto(plan.url, { waitUntil: 'domcontentloaded', timeout: plan.timeout ?? 30000 });
  await page.waitForTimeout(1500);
  await shoot(page, 'start');
  seenBlockers = await blockers(page);

  for (const [i, step] of plan.steps.entries()) {
    try {
      await runStep(step, i);
    } catch (e) {
      // The failure frame is the most useful picture the run produces, so it is
      // taken before anything unwinds.
      const shot = await shoot(page, `FAIL-step-${i + 1}-${step.do}`).catch(() => null);
      results.push({ n: i + 1, ...step, ok: false, error: String(e.message || e).slice(0, 300),
                     url: page.url(), screenshot: shot });
      failed = { step: i + 1, error: String(e.message || e).slice(0, 300) };
      break;
    }
  }

  if (!failed) await shoot(page, 'end');
} finally {
  await context.close().catch(() => {});
  await browser.close().catch(() => {});
}

const report = { url: plan.url, mode: plan.mode || 'strict', ran: results.length,
                 total: plan.steps.length, failed, blockers: seenBlockers,
                 consoleErrors: consoleErrors.slice(0, 10), screenshots: shots, steps: results };
writeFileSync(join(outDir, 'report.json'), JSON.stringify(report, null, 2));

console.log('=== BROWSER RUN ===');
console.log(`url:   ${plan.url}`);
console.log(`mode:  ${report.mode}`);
console.log(`steps: ${results.length} of ${plan.steps.length}`);
console.log('');
for (const r of results) {
  const mark = r.ok ? 'ok  ' : 'FAIL';
  console.log(`  ${mark} ${String(r.n).padStart(2)}. ${r.do}${r.selector ? ' ' + r.selector : ''}` +
              `${r.note ? '  (' + r.note + ')' : ''}`);
  if (!r.ok) console.log(`       ${r.error}`);
  if (r.screenshot) console.log(`       ${r.screenshot}`);
}
if (seenBlockers.length) {
  console.log('\noverlays present on arrival, not dismissed, a plan must handle them:');
  for (const b of seenBlockers) console.log('  ' + b);
}
if (consoleErrors.length) {
  console.log('\nconsole errors seen:');
  for (const e of consoleErrors.slice(0, 5)) console.log('  ' + e);
}
console.log(`\nscreenshots: ${shots.length} in ${outDir}`);
console.log(`report:      ${join(outDir, 'report.json')}`);
console.log(failed ? `\nSTOPPED at step ${failed.step}. ${failed.error}` : '\nplan completed.');
console.log('=== END ===');
process.exit(failed ? 2 : 0);
