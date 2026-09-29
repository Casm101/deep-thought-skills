---
name: dt-explainer
description: 'Build an animated explainer of a change, an article or a concept, as code that draws every frame rather than generated pixels. Produces one self-contained HTML page with play and scrub controls, chaptered captions, light and dark themes, optional procedural sound, and a frame exact PNG or MP4 export. Defaults to explaining the work on the current branch, read from its own diff. Confirms a storyboard before drawing anything, and verifies the result by exporting a still of every scene and looking at it. Use when asked for "dt explainer" or "deep thought explainer", or to animate a change, make an explainer or a walkthrough video, or show visually how something works.'
argument-hint: "Nothing for the current branch, or a URL, a path, or a concept to explain."
---

# dt-explainer

Explain something by drawing it, with code that produces every frame. Because the output is code
rather than pixels, it can be edited, diffed, re-themed and re-exported at any resolution. The
approach is Addy Osmani's "animations from code".

It suits anything with real geometry, motion and timing: data flow, request lifecycles, state
machines, caches, render pipelines, and before and after behaviour. It suits a prose summary badly.

Two files do the work, and neither is written from scratch on a run:

- `assets/template.html` is the runtime. Fixed 1920x1080 drawing space, scene timeline, controls,
  captions, theme tokens, procedural audio, export hooks. **Copy it, never rewrite it.**
- `scripts/explainer-export.sh` renders frames, and is how the result gets checked.

## Phase 1. Find the source

The default is the work on the current branch.

```bash
git log --oneline origin/HEAD..HEAD
git diff origin/HEAD...HEAD --stat
```

Then read the diffs of the three to six files carrying the behaviour. Skip tests, snapshots,
generated code and lockfiles. Read the intent where it exists, in a spec, the PR description, or the
Jira ticket.

Write down the story in one sentence before anything else: what was wrong or missing, what the change
does, and what is different now. A storyboard drawn without that sentence has no arc.

A URL, a path or a concept given as an argument replaces the branch as the source. Fetch a URL and use
its content.

## Phase 2. Storyboard, then ask once

Four to seven scenes, thirty to sixty seconds total. Each scene carries a one to three word title, a
caption of at most fourteen words, a duration between four and ten seconds, and the visual idea.

The arc that works for a change is context, then the problem happening, then the mechanism, then the
same scenario behaving differently, then the takeaway.

**Use the real names from the code.** Files, hooks, endpoints, query keys. An explainer with invented
components teaches the wrong system, and it is worse than none.

Show the storyboard as a numbered list, then make **one** `AskUserQuestion` call covering the
storyboard, sound, and length where the source clearly needs more or less than sixty seconds. Sound is
off unless asked for.

**Draw nothing until the storyboard comes back confirmed.** Six scenes against the wrong story is the
expensive mistake this skill has, and it is the only place worth spending a turn.

## Phase 3. Build

Output goes to `~/explainers/<slug>/<slug>.html`. Never into a repository, tracked or not.

Copy the template, fill `{{TITLE}}` with two to four words that name the thing rather than describe
it, and `{{DESCRIPTION}}` with one sentence. Set `CONFIG.audio` from the sound answer. Replace the
example `SCENES` with the storyboard, each one `{ id, title, caption, dur, sfx?, draw(p, t) }`.

`references/drawing-kit.md` holds the kit, the rules `draw` has to obey for the export to work, the
sound cues, and what each failure looks like. Read it before writing a scene, because the constraints
on `draw` are not guessable and breaking them produces a page that plays correctly and exports wrong.

Run `dt-unslop` over the captions before they go in. They are the only prose here, a viewer reads
every one, and fourteen words leave no room for a tell.

## Phase 4. Verify by looking

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-explainer/scripts/explainer-export.sh <file.html> --stills <dir>
${CLAUDE_PLUGIN_ROOT}/skills/dt-explainer/scripts/explainer-export.sh <file.html> --stills <dir>-light --theme light
```

Stills need no ffmpeg. The script exits non-zero when the page threw, and a zero exit only means it
rendered.

**Then read every PNG.** Each is taken 75% through its scene. Look for overlapping shapes, clipped or
undersized text, anything hidden under the caption, contrast in both themes, and whether the picture
shows what its caption claims. Fix and rerun until clean, then delete the stills unless they were
asked for.

A run that exported cleanly and was never looked at has verified nothing. The stills exist to be
read, and this is the phase that gets skipped.

## Phase 5. Deliver

Give the path and `open <file.html>`. Then offer, in one line rather than a question round, an MP4 and
a private Artifact link.

MP4 needs ffmpeg, which the wrapper checks for before rendering anything. It is not installed on this
machine today, so that offer currently means asking the user to run `brew install ffmpeg` first.
Never install it for them.

For the Artifact, load `artifact-design` and check the page against it. The template already satisfies
most of it: a short title, both theme blocks, an explicit body background, no external scripts, and a
phone width layout.

## Never

- Never write an explainer into a repository, tracked or untracked.
- Never draw a component, file or endpoint that is not in the source. An explainer that invents
  structure teaches a system nobody has.
- Never start building before the storyboard is confirmed.
- Never hard-code a colour in a scene. Theme tokens only, or one of the two themes breaks.
- Never let `draw` read state, call `Math.random`, `Date.now` or a timer. Seeking to a time must give
  the same frame every time, and the export depends on it.
- Never turn sound on unless it was asked for.
- Never install ffmpeg. Say what is missing and let the user decide.
- Never report an explainer as verified without having read the stills.
- Never rewrite `assets/template.html` to suit one explainer. Add a scene-local helper instead.

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.
