---
name: dt-mod-creator
description: 'Build a Claude Code mod, a plugin of function hooks that draws a band above the prompt, a pane, a status line or a toast, guards or rewrites tool calls, adds a slash command, or runs a small game, and ship it from deep-thought-skills. Confirms a short sketch first, builds under mods/<name>/ on top of the built-in plugin-authoring skill, proves it with validate, typecheck and plugin tests on the terminal and desktop, loads it live by hot reload, and only once the person says it looks good commits it, fast-forwards main and installs it at user scope. Use when asked for "dt mod creator" or "deep thought mod creator", or to make, build or write a mod, a hooks plugin, a band, pane or status line inside Claude Code, or a game to play while Claude works. On this machine use it rather than plugin-authoring alone, which cannot write past the dev-mods fence.'
argument-hint: "What the mod should do, in a sentence."
---

# dt-mod-creator

Build a mod, show it running, and ship it only when the person has seen it.

A mod is a plugin whose `hooks/hooks.json` names a hooks module. That module runs inside Claude Code
and can draw, guard, rewrite and react. Claude Code's built-in `plugin-authoring` skill knows the
API for the exact build in use, and its `claude-code.d.ts` is the authority on every event, noun and
element. This skill adds what that one cannot know: where mods live, the admin fence on this
machine, the gaps in the test kit, and how a mod reaches `main` and the person's install.

**Rules that hold throughout.**

- Mods live in deep-thought-skills under `mods/<name>/`, listed in the repo's marketplace. Never
  under `plugins/`, where the lint fails any plugin with no skills.
- The d.ts outranks every reference here and every page of the docs. Grep it with Bash, since the
  fenced `Read` refuses its path.
- Mods draw on the terminal and the desktop Code tab only. Every `ui.render` hook answers `next(e)`
  on any other `e.surface`.
- Nothing is committed until the person has said it looks good.

## Phase 1. Check the ground

Find the repository. It is the current checkout when `git remote get-url origin` names
`Casm101/deep-thought-skills`, a desktop worktree included, and otherwise
`~/Documents/Github/deep-thought/deep-thought-skills`. Call it `R`. Then run the preflight:

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-mod-creator/scripts/mod-check.sh env <name> "$R"
```

It prints the session's own Claude Code build, the Homebrew one, the branch and how it sits
against `origin/main`, whether the SSH key is loaded, whether the name is free, and whether
`.gitignore` already ignores the types the engine lays beside a mod. Carry every `warn` line to the
hand back. A taken name stops the run until the person picks another.

## Phase 2. Sketch it and confirm once

Map the ask to a shape with the table `plugin-authoring` prints, then write the sketch:

- the name, and what it does in one sentence
- the events it hooks and the sites it draws in, each marked with where it shows (see the surface
  table in `references/building.md`; `ToolProgress`, `TurnDuration`, `InfoNotice`, `Raster` and
  `Image` are terminal only)
- the values it keeps, in `$.state` for the session or `$.store` across sessions
- the commands it registers and the keys it takes
- any behaviour the never list says to flag, named plainly

Run `dt-unslop` over the sketch, then make **one** `AskUserQuestion` call to confirm it. Where the ask
leaves real design forks that one question cannot settle, run `dt-grilling` instead and come back
with its tree.

**Write no code before the sketch is confirmed.** A wrong `Client` module is a day of rework, and a
wrong sketch is one question.

## Phase 3. Load plugin-authoring, then build

Invoke the built-in `plugin-authoring` skill with the Skill tool. It names this build's types file
and the session's dev-mods folder, and it starts the watch that Phase 5 relies on. Read its examples
for the shape you sketched, and grep the d.ts for every event and element you use.

Then write the mod under `$R/mods/<name>/`, following `references/building.md`: the manifest, the
hooks list, the module, the state contract when there is one, a `Client` module for anything
animated, the tests, a README, the marketplace entry and the `.gitignore` line.

Run `dt-unslop` over the README and over every string the mod shows a person: toasts, status
text, command replies, button labels.

## Phase 4. Prove it

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-mod-creator/scripts/mod-check.sh check "$R/mods/<name>"
```

It runs `plugin validate`, a typecheck and `plugin test`, on the session's own build. Fix and rerun
until all three pass. Then, per `references/proving.md`, print the drawn frames of anything the mod
draws, and for an interactive mod write a throwaway bot test that plays it. Delete the bot test once
it passes.

**A suite that passes has not shown the mod is usable.** The frames and the bot are what show it.

## Phase 5. Load it live

The admin fence refuses any write under `~/.claude/dev-mods/`, and a Bash write there would only
sidestep it. So the person makes the link. Give them exactly one line, with the folder
`plugin-authoring` named:

```bash
ln -s "$R/mods/<name>" ~/.claude/dev-mods/$CLAUDE_CODE_SESSION_ID/<name>
```

They answer "Enable hot reloading for this session?" themselves. The mod loads when the turn ends,
and every later edit reloads it at the end of the turn that made it. For a terminal session, offer
`claude --plugin-dir "$R/mods/<name>"` as well.

Read the notice that opens the next turn. On `enabled`, look for a dim line naming the mod, which
means a hook failed or a tree was refused, and fix it before asking. On `declined` or `off`, say so.
The confirmation in Phase 6 then rests on the frames alone.

## Phase 6. Ask whether it looks good

One `AskUserQuestion`: ship it, change something, or abandon it.

- **Change.** Edit, let it reload, rerun Phase 4, ask again. As many rounds as it takes.
- **Abandon.** Stop. The files stay uncommitted in `mods/<name>/`; say where. Deleting them is
  the person's call.
- **Ship.** Go on.

## Phase 7. Commit and fast-forward main

`references/shipping.md` has the exact sequence and its traps. In short, check the branch again,
run the repo lint, commit only the mod's files, and push `HEAD:main` only when that is a
fast-forward of a freshly fetched `origin/main` carrying this one commit. Anything else stops and
asks.

## Phase 8. Install it and hand back

Install from the marketplace at user scope, ask the person to remove the dev link, then
`/reload-plugins`, per `references/shipping.md`. Two copies run otherwise, `<name>@inline` and
`<name>@deep-thought-skills`.

Hand back the mod's path and commit, what it hooks (from `validate`), where it shows, the install
line for anyone else, every flagged behaviour, and the preflight's warnings. If the run taught
something new about mods, record it with `dt-memory` in the store's `work/tooling` state document.

## Never

- Never write under `~/.claude/dev-mods/`, with any tool. The person makes the link.
- Never answer, pre-empt or work around the hot reload question, and never edit `settings.json`
  to load a mod.
- Never commit before the person says it looks good, and never commit files outside the mod,
  its marketplace entry and the `.gitignore` line.
- Never push anything but a fast-forward of `origin/main`, never force, and never push from a
  branch carrying other work.
- Never enter an SSH passphrase or change a remote. Commit, stop, and hand over `ssh-add`.
- Never upgrade Claude Code. Say which build is too old.
- Never build a mod that monitors, scores or profiles a person, whoever asks.
- Never build a mod that approves tool calls, overrides deny rules or sends session content off
  the machine unless the person asked for that behaviour by name. When they did, flag it in the
  sketch and again at hand back.
- Never draw on `vscode` or `mobile`, and never copy the API into this skill's references.
- Never leave the bot test in the mod.

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.
