# What a dt skill is made of

```
<name>/
  SKILL.md              always
  references/*.md       when SKILL.md would otherwise run long
  scripts/*.sh          when there is deterministic work to do
```

## Naming

`dt-<verb-or-noun>`, lower case, hyphenated. The prefix is what keeps these from colliding with
repo-local skills, so it is not optional.

The directory name and the frontmatter `name` must match exactly. The validator checks it because
getting it wrong makes the skill unloadable in a way that is hard to spot.

## Frontmatter

```yaml
---
name: dt-thing
description: <what it does, what it needs, what it gives back, and when to use it>
---
```

Optional fields worth knowing:

- `argument-hint`, one line shown to the user about what to pass.
- `disable-model-invocation: true`, so only a person can run it. Use this whenever running the skill
  writes something a session cannot easily undo, or when it only makes sense as a deliberate act.

The description is the whole trigger. It decides whether the skill loads at all, so write it for a
reader who has never seen the skill:

- Say what it does first, in one sentence.
- Say what it needs and what it hands back.
- End with the phrases that should reach it, including both `"dt thing"` and `"deep thought thing"`,
  plus the plain-English asks a person would actually type.
- Do not describe the implementation. Nobody triggers a skill on its phase names.

## SKILL.md

Phases, numbered, in the order they run. Each phase says what to do, what to read, and what it hands
to the next one.

What belongs here rather than in a reference:

- The phases themselves, and the order.
- The rules that hold across all of them, up top.
- The never-list, at the bottom. Every skill that writes anything needs one.
- The one or two decisions the skill exists to get right.

What belongs in a reference instead:

- Long formats, templates and worked examples.
- Command sequences with their traps.
- Taxonomies, tables of verdicts, checklists.

Rule of thumb: if `SKILL.md` passes about 150 lines, something in it is a reference.

## references/

One file per concern, named for what it holds, `installing.md` rather than `notes.md`. Every reference
must be mentioned from `SKILL.md` at the point it is needed, because an unmentioned reference does not
get read.

Worked examples earn their place. A format described in prose gets interpreted three ways; a format
shown once gets copied.

## scripts/

Write a script when the work is deterministic and repeated: recon, validation, gathering context,
computing a decision from numbers. Do not write one for anything that needs judgement.

- **Read-only by default.** Print to stdout, write nothing. Where a temp file is unavoidable, put it
  in `${TMPDIR:-/tmp}` and print the path, never in the user's repo.
- `#!/usr/bin/env bash` and `set -uo pipefail`. Not `-e`, which turns a harmless non-zero test into an
  exit.
- Fail with a clear message naming the fix, not a stack trace.
- Make the output readable by a person, since a person will be the one debugging it.
- **Test it against a real repository before shipping.** Every script in this family had a bug that
  only appeared on real data: a stem match that called an unrelated file a test, a phrase grep that
  missed a line wrap, a commit count inflated by a merge.

## The house style

`dt-unslop` governs the prose. Beyond that:

- Sentence case headings, `## Phase 3. Do the thing`.
- Bold lead-ins end with a period, not a colon.
- Second person, present tense, imperative. "Read the diff", not "the diff should be read".
- State the trap, not the happy path. The value of these files is the thing that goes wrong.
- Say what it must never do, and mean never.
