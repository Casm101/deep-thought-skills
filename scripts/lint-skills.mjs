#!/usr/bin/env node
// Dependency-free STRUCTURAL linter for this repository's plugin, skills, commands and manifests.
// It is the whole-repo gate; dt-skill-creator's validate-skill.sh is the per-skill authoring tool
// and adds house-style warnings on top.
//
// Checks: manifests are valid JSON and agree on the plugin name; per skill, frontmatter name
//   matches the directory, the description is present, third-person and free of the ": " that
//   silently voids a YAML scalar; the body stays under 500 lines; every referenced references/ file
//   exists; every ${CLAUDE_PLUGIN_ROOT} path resolves and each named script is executable; nothing
//   still points at ~/.claude/skills; a command wrapper exists and reads the right SKILL.md; and the
//   router names every skill.
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, relative } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const DESC_MAX = 1024; // dual invocation (slash + natural language) wants room for trigger phrases
const FIRST_PERSON = /\b(I|I'm|I'll|my|me)\b/;
// dt-memory installs to ~/.claude/skills from the deep-thought-store repo and is not in this plugin,
// so a path naming it is correct rather than stale.
const STALE_PATH = /\.claude\/skills\/[A-Za-z$]/;

let failures = 0;
const fail = (msg) => { console.error(`  ✗ ${msg}`); failures++; };
const pass = (msg) => console.log(`✓ ${msg}`);
const walk = (dir) => readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
  e.isDirectory() ? walk(join(dir, e.name)) : [join(dir, e.name)]);

// ---- manifests -------------------------------------------------------------
const readJson = (p, label) => {
  try { const j = JSON.parse(readFileSync(p, 'utf8')); pass(`${label} valid JSON`); return j; }
  catch (e) { fail(`${label}: ${e.message}`); return null; }
};
const mkt = readJson(join(root, '.claude-plugin', 'marketplace.json'), '.claude-plugin/marketplace.json');

const pluginsRoot = join(root, 'plugins');
const pluginDirs = existsSync(pluginsRoot)
  ? readdirSync(pluginsRoot).map((n) => join(pluginsRoot, n))
      .filter((p) => existsSync(join(p, '.claude-plugin', 'plugin.json')))
  : [];
if (!pluginDirs.length) fail('no plugin found under plugins/* (expected .claude-plugin/plugin.json)');

for (const pluginDir of pluginDirs) {
  const rel = (p) => relative(root, p);
  const manifest = readJson(join(pluginDir, '.claude-plugin', 'plugin.json'), `${rel(pluginDir)}/.claude-plugin/plugin.json`);

  // The install string is <plugin>@<marketplace>, so a mismatch here is an install that cannot resolve.
  if (manifest && mkt) {
    const listed = (mkt.plugins || []).map((p) => p.name);
    if (!listed.includes(manifest.name)) fail(`marketplace.json does not list the plugin "${manifest.name}" (lists: ${listed.join(', ') || 'none'})`);
    else pass(`marketplace lists "${manifest.name}"`);
  }

  const skillsDir = join(pluginDir, 'skills');
  const commandsDir = join(pluginDir, 'commands');
  if (!existsSync(skillsDir)) { fail(`${rel(pluginDir)}/skills missing`); continue; }

  const skillNames = readdirSync(skillsDir).filter((n) => existsSync(join(skillsDir, n, 'SKILL.md'))).sort();
  if (!skillNames.length) fail(`${rel(pluginDir)}/skills holds no SKILL.md`);

  const routerPath = join(skillsDir, 'dt-ask-deepthought', 'SKILL.md');
  const router = existsSync(routerPath) ? readFileSync(routerPath, 'utf8') : null;
  if (!router) fail('dt-ask-deepthought/SKILL.md missing (the router)');

  for (const name of skillNames) {
    const skillDir = join(skillsDir, name);
    const src = readFileSync(join(skillDir, 'SKILL.md'), 'utf8');
    const fm = src.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
    if (!fm) { fail(`${name}: no frontmatter block`); continue; }
    const [, front, body] = fm;
    const get = (key) => {
      const line = front.split('\n').find((l) => l.startsWith(`${key}:`));
      return line ? line.slice(key.length + 1).trim() : null;
    };

    const nameVal = get('name');
    const desc = get('description');
    if (nameVal !== name) fail(`${name}: frontmatter name "${nameVal}" != directory "${name}"`);
    if (!desc) fail(`${name}: missing description`);
    else {
      if (desc.length > DESC_MAX) fail(`${name}: description ${desc.length} chars (> ${DESC_MAX})`);
      // An unquoted YAML scalar containing ": " parses as a mapping and the frontmatter silently drops.
      if (/:\s/.test(desc) && !/^['"]/.test(desc)) fail(`${name}: description has ": " in an unquoted scalar — quote it or drop the colon`);
      if (FIRST_PERSON.test(desc.replace(/"[^"]*"/g, ''))) fail(`${name}: description is not third-person`);
    }

    const bodyLines = body.split('\n').length;
    if (bodyLines >= 500) fail(`${name}: body ${bodyLines} lines (>= 500)`);

    const files = walk(skillDir).filter((f) => /\.(md|sh)$/.test(f));

    // Nothing may reach for ~/.claude/skills: that holds personal skills, not this plugin.
    for (const f of files) {
      readFileSync(f, 'utf8').split('\n').forEach((line, i) => {
        if (STALE_PATH.test(line) && !line.includes('dt-memory')) {
          fail(`${relative(skillsDir, f)}:${i + 1} points at ~/.claude/skills, which does not hold this plugin`);
        }
      });
    }

    // Every referenced sibling skill and script must exist; a named script must be executable.
    const text = files.map((f) => readFileSync(f, 'utf8')).join('\n');
    for (const ref of new Set([...text.matchAll(/skills\/(dt-[a-z-]+)/g)].map((m) => m[1]))) {
      if (ref !== 'dt-memory' && !skillNames.includes(ref)) fail(`${name}: references skill "${ref}", which is not in this plugin`);
    }
    for (const ref of new Set([...text.matchAll(/skills\/(dt-[a-z-]+\/scripts\/[A-Za-z0-9_.-]+\.sh)/g)].map((m) => m[1]))) {
      const target = join(skillsDir, ref);
      if (!existsSync(target)) fail(`${name}: names a script that does not exist: skills/${ref}`);
      else if (!(statSync(target).mode & 0o111)) fail(`${name}: names a script that is not executable: skills/${ref}`);
    }
    for (const ref of new Set([...src.matchAll(/references\/[a-z0-9-]+\.md/g)].map((m) => m[0]))) {
      if (!existsSync(join(skillDir, ref))) fail(`${name}: ${ref} is referenced but missing`);
    }

    // The wrapper is what makes /<name> work, and it is the only route into a skill that
    // carries disable-model-invocation: true.
    const cmd = join(commandsDir, `${name}.md`);
    if (!existsSync(cmd)) fail(`${name}: no command wrapper at commands/${name}.md`);
    else if (!readFileSync(cmd, 'utf8').includes(`skills/${name}/SKILL.md`)) {
      fail(`commands/${name}.md does not read skills/${name}/SKILL.md`);
    }

    if (router && name !== 'dt-ask-deepthought' && !router.includes(`\`${name}\``)) {
      fail(`${name}: the router does not name it`);
    }

    if (!failures) pass(`${name}: ok (desc ${desc ? desc.length : '—'} chars, body ${bodyLines} lines)`);
  }

  // A wrapper with no skill behind it is a dead slash command.
  if (existsSync(commandsDir)) {
    for (const f of readdirSync(commandsDir).filter((n) => n.endsWith('.md'))) {
      const n = f.replace(/\.md$/, '');
      if (!skillNames.includes(n)) fail(`commands/${f} has no skill at skills/${n}`);
    }
  }

  console.log(`\n${skillNames.length} skills, ${existsSync(commandsDir) ? readdirSync(commandsDir).length : 0} commands.`);
}

if (failures) { console.error(`\n${failures} problem(s).`); process.exit(1); }
console.log('All skills lint clean.');
