# Wiring and shipping a new skill

## Where a skill lives

One tree, the `deep-thought-skills` repository, cloned at
`~/Documents/github/deep-thought/deep-thought-skills`:

```
plugins/deep-thought/skills/<name>/       the skill
plugins/deep-thought/commands/<name>.md   the wrapper that makes it a slash command
```

There is no separate installed copy to keep in step. Claude Code installs the plugin into its own
cache and reads it from there, so a session sees the last version you **pushed**, never your working
tree. That is the one surprise worth holding on to: writing the files changes nothing until you
commit, push, and update the plugin.

To try a skill before pushing it, add the working clone as a second marketplace:

```bash
claude plugin marketplace add ~/Documents/github/deep-thought/deep-thought-skills
```

Write files with a **quoted** heredoc when going through bash:

```bash
cat > "$SRC/SKILL.md" <<'EOF'
...content...
EOF
```

Quoted, because skill files are full of backticks, `$`, and `{{braces}}`, and an unquoted heredoc runs
the backticks as commands and eats the rest.

## Paths inside a skill

A skill cannot reach itself through `~/.claude/skills`: that directory holds personal skills, not this
plugin. Every path to its own scripts or references, and every path to a sibling, goes through
`${CLAUDE_PLUGIN_ROOT}`, which Claude Code substitutes when it reads the markdown:

```
${CLAUDE_PLUGIN_ROOT}/skills/<name>/scripts/<script>.sh
${CLAUDE_PLUGIN_ROOT}/skills/<name>/references/<file>.md
```

**Scripts cannot rely on that variable**, because it is a markdown substitution and not something the
shell is guaranteed to have. A script that needs its siblings resolves the tree from its own location:

```bash
SKILLS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
```

## Make the scripts executable

```bash
chmod +x plugins/deep-thought/skills/<name>/scripts/*.sh
git update-index --chmod=+x plugins/deep-thought/skills/<name>/scripts/*.sh
```

The bit has to be **committed**, not just set locally. A script that arrives non-executable on another
machine fails at the skill's first command, and the mode is the only part of the file git will happily
drop.

## Write the command wrapper

`plugins/deep-thought/commands/<name>.md`, the same five lines as every sibling:

```markdown
---
description: <the one-line summary, matching the skill>
---
Read `${CLAUDE_PLUGIN_ROOT}/skills/<name>/SKILL.md` and execute it exactly as written, treating
the following as the user's input/arguments: $ARGUMENTS
```

The validator fails a skill with no wrapper. It is what makes `/<name>` work, which matters most for
the skills carrying `disable-model-invocation: true`, since a description will never reach them.

## Wire it into the router

`dt-ask-deepthought` needs **three** edits, and missing one is the usual mistake:

1. **The map**, so it appears in the flow, or under on-ramps, standalone, or underneath.
2. **The roster table**, one row: when to use it, what it needs, what it gives back.
3. **The decision list**, one numbered step, placed by when it should win.

Adding to the decision list means **renumbering every step after it**. Do that in one pass and read
the list back afterwards, because a duplicated number is invisible until someone follows it.

Do not touch the router's own description.

## Update the README roster

`README.md` lists every skill in the kit. A skill missing from it is invisible to anyone reading the
repo, including you on a machine where you have forgotten what is in here.

## Update the memory note

The family is tracked in a memory file under the project's memory directory. It carries the count, the
list, and the topology. Update all three, or the next session works from a stale roster.

## Validate

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-skill-creator/scripts/validate-skill.sh <name>
${CLAUDE_PLUGIN_ROOT}/skills/dt-skill-creator/scripts/validate-skill.sh --all
```

Run `--all` too. Wiring one skill has broken another more than once, usually by a rename that reached
further than intended.

It checks the frontmatter name against the directory, the description length, that every referenced
`references/` file exists, that scripts are executable and parse, that internal script paths resolve,
house style, that the command wrapper exists, that the router mentions it, and that no path still
points at `~/.claude/skills`. That last one is the mistake that survives a move into the plugin and
then fails silently.

## Traps that have cost time here

**The shell is zsh.** `for x in $var` does not word-split an unquoted variable, so a loop over a
newline-separated list runs once with the whole thing. Run multi-item loops under `bash <<'EOF'`, or
use an explicit array.

**Grep misses line-wrapped phrases.** Searching for "blast radius" finds nothing when the file wraps
between the two words. Search single words when checking whether something is really gone.

**Editing by replacing a block can leave the old one.** A replacement that appends instead of
substituting produced a duplicated checklist glued onto the end of a sentence, and it survived several
passes. After any block edit, read the section back.

**A `cd` into a repo can trigger a shell hook.** In at least one repo here, `cd` fires a node version
manager that tries to compile node from source, hangs for minutes, and returns non-zero, which kills
any `&&` chain after it. Use `;` instead, or do not `cd` when the session is already there.

**Renames touch more than the directory.** The frontmatter `name`, every internal
`${CLAUDE_PLUGIN_ROOT}/skills/<name>/...` path, the command wrapper's filename and its body, the
router's three places, the README roster, and the memory note. A rename that only moved the directory
left a skill pointing at another skill's script. Run the validator with `--all` afterwards.
