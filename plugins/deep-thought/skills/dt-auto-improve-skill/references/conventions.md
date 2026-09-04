# The conventions an edit has to respect

Copied from `dt-skill-creator` so this skill can work without reading it. **If the two ever disagree,
`dt-skill-creator` is the original and this copy is the one that needs updating.** Say so when you
notice a difference rather than following the nearest text.

## Where the files live

One tree, the `deep-thought-skills` repository:

```
plugins/deep-thought/skills/<name>/     the skill
plugins/deep-thought/commands/<name>.md the wrapper that makes it a slash command
```

There is no second copy to keep in step. An edit is a commit, and every machine picks it up on its
next `claude plugin update`.

The clone Claude Code reads from is not the one you edit. It installs the plugin into its own cache,
so a session running the plugin sees the last version you pushed, not your uncommitted work. To try
an edit before pushing it, add the working clone as a second marketplace:

```bash
claude plugin marketplace add ~/Documents/github/deep-thought/deep-thought-skills
```

Scripts need their executable bit committed, or the skill fails at its first command:

```bash
chmod +x plugins/deep-thought/skills/<name>/scripts/*.sh
git update-index --chmod=+x plugins/deep-thought/skills/<name>/scripts/*.sh
```

## The shape of a skill

```
<name>/
  SKILL.md              always
  references/*.md       when SKILL.md would otherwise run long
  scripts/*.sh          when there is deterministic work to do
```

`SKILL.md` holds the phases in order, the rules that hold across all of them, and the never-list at
the bottom. Long formats, worked examples, command sequences and taxonomies belong in a reference.

**Past about 150 lines, something in `SKILL.md` belongs in a reference.** Several skills in this suite
are close to that, so growth is a reason to move something out.

Every reference must be mentioned from `SKILL.md` at the point it is needed. An unmentioned reference
does not get read.

## Frontmatter

```yaml
---
name: dt-thing            # must match the directory exactly
description: <what it does, what it needs, what it hands back, when to use it>
---
```

Optional and occasionally right: `argument-hint`, and `disable-model-invocation: true` where only a
person should be able to run it.

The description is the trigger and decides whether the skill loads at all. It is not documentation, so
a lesson never lands there.

## Scripts

- `#!/usr/bin/env bash` and `set -uo pipefail`. Not `-e`, which turns a harmless failing test into an
  exit.
- Read-only by default, printing to stdout. A temp file goes in `${TMPDIR:-/tmp}` and its path gets
  printed, never inside the user's repo.
- Fail with a message naming the fix.
- **Test against real data before shipping.** Every script in this suite had a bug that only appeared
  on a real repository.

## The house style

`dt-unslop` governs the prose. On top of that:

- Sentence case headings, `## Phase 3. Do the thing`.
- Bold lead-ins end with a period, not a colon.
- Second person, present tense, imperative. "Read the diff", not "the diff should be read".
- State the trap, not the happy path. The value of these files is the part that goes wrong.
- No em dashes anywhere, no curly quotes, no decorative emoji.

## The traps that have actually cost time here

**A block edit can leave the old block behind.** A replacement that appends rather than substitutes
produced a duplicated checklist glued onto the end of a sentence, and it survived several passes. Read
the section back after any block edit.

**The shell is zsh.** `for x in $var` does not word-split an unquoted variable, so a loop over a
newline-separated list runs once with the whole thing. Use `bash <<'EOF'` or an explicit array.

**Grep misses line-wrapped phrases.** Searching for a two-word phrase finds nothing when the file
wraps between the words. Search single words when checking whether something is really gone.

**An anchor you paraphrased will not match.** Copy the exact text before replacing it. A failed
assertion mid-script means nothing was written, including the edits that had already succeeded.

**The tree is version controlled**, so `git diff` is the review and `git checkout --` is the undo.
Keep the working tree clean before you start, or you cannot tell your edit from what was already
there.

## Editing the router

`dt-ask-deepthought` needs three edits when a skill is added, and this skill does not add skills, so it
usually needs none. If an edit changes what a skill is for, its roster row and decision step may need
to change with it, and the decision list must be renumbered from one in a single pass afterwards.

## The validator

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-skill-creator/scripts/validate-skill.sh <name>
${CLAUDE_PLUGIN_ROOT}/skills/dt-skill-creator/scripts/validate-skill.sh --all
```

It checks the frontmatter name against the directory, the description, that referenced files exist,
that scripts are executable and parse, internal script paths, house style, the command wrapper, and
the router mention. It also fails any path still pointing at `~/.claude/skills`, which is the one
mistake that survives into the plugin and then fails silently. Run `--all` after any edit, because a
shared reference or a cross-skill mention has broken a sibling before.
