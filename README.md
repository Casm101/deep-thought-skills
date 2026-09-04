# deep-thought-skills

The `dt-*` workflow skills, packaged as a Claude Code plugin so every machine runs the same set.

They used to live in two hand-copied trees on one laptop: `~/Documents/claude-skills` for editing and
`~/.claude/skills` for running. This repository is now the only copy. An edit is a commit, and every
other machine picks it up with `claude plugin update`.

**Private on purpose.** Two skills carry internal LeoVegas detail: `dt-pr-slack-message` holds the
`#pt-sports-frontend-prs` channel id and two colleagues' Slack ids, and `dt-test-account` holds
internal staging hostnames and the testapp endpoint. Do not make this repository public with those in
it.

## Install

```bash
claude plugin marketplace add Casm101/deep-thought-skills
```

```bash
claude plugin install deep-thought@deep-thought-skills
```

`deep-thought@deep-thought-skills` reads as `<plugin>@<marketplace>`. `Casm101/deep-thought-skills` is
the GitHub repo and is used only by `marketplace add`.

Or declaratively, in `~/.claude/settings.json` (see [examples/consumer-settings.json](./examples/consumer-settings.json)):

```json
{
  "extraKnownMarketplaces": {
    "deep-thought-skills": {
      "source": { "source": "github", "repo": "Casm101/deep-thought-skills" },
      "autoUpdate": true
    }
  },
  "enabledPlugins": { "deep-thought@deep-thought-skills": true }
}
```

The repo is private, so `autoUpdate` needs a token to authenticate at startup. Add
`export GH_TOKEN=…` to `~/.zshrc`, or skip it and update manually with your normal `gh` login.

### One-time, on the machine that already has them

Installing the plugin while `~/.claude/skills/dt-*` still exists gives you **every skill twice**, and
the two copies drift the moment you edit one. Retire the local ones. This moves rather than deletes,
and skips `dt-memory`, which is a symlink and stays:

```bash
mkdir -p ~/.claude/skills-retired && for d in ~/.claude/skills/dt-*; do [ -L "$d" ] || mv "$d" ~/.claude/skills-retired/; done
```

`~/Documents/claude-skills` is now stale too. Keep it until you trust the plugin, then delete it, or
it becomes a second source of truth that quietly disagrees with this one.

## The skills

One flow runs from a branch to an open PR. `dt-implement` is the only skill that writes code or
commits; `dt-ship` is the only one that pushes or opens a PR.

| | |
|---|---|
| **The flow** | `dt-create-branch` → `dt-investigation` → `dt-grilling` → `dt-to-tasks` → `dt-tdd-prep` → `dt-implement` → `dt-ship` → `dt-pr-data` |
| **Review** | `dt-code-review` (one agent), `dt-overkill-code-review` (three models, judged), `dt-pr-review` (posts on a PR), `dt-pr-defense` (answers the feedback) |
| **Branches** | `dt-branch-update`, `dt-merge-conflicts`, `dt-inherit-branch`, `dt-handoff` |
| **sportsbook-ui** | `dt-storybook-creator`, `dt-tailwind-migration-tool`, `dt-test-account`, `dt-pr-slack-message`, `dt-ticket-refiner` |
| **Writing** | `dt-unslop` (all prose), `dt-unslop-code` (comments a change left behind) |
| **Unattended** | `dt-auto-develop` runs the whole flow from a ticket and stops rather than guessing |
| **The suite itself** | `dt-skill-creator` (new skills), `dt-auto-improve-skill` (fold a lesson back in) |

Ask **`dt-ask-deepthought`** which one fits instead of remembering the set. Every skill also has a
`/dt-<name>` slash command, which is the only way into the three that carry
`disable-model-invocation: true` (`dt-handoff`, `dt-skill-creator`, `dt-ticket-refiner`).

### dt-memory is not in here

`dt-memory` belongs to [deep-thought-store](https://github.com/Casm101/deep-thought-store) and installs
from there. Four skills read it and degrade gracefully when it is absent, so the plugin works without
it. To have it on a machine, clone that repo and link the skill:

```bash
ln -s ~/Documents/github/deep-thought/deep-thought-store/skill/dt-memory ~/.claude/skills/dt-memory
```

## Update

Two layers move, and missing the second is the usual reason nothing changed: refresh the marketplace
catalog, then update the installed plugin.

```bash
claude plugin marketplace update deep-thought-skills && claude plugin update deep-thought@deep-thought-skills
```

Then `/reload-plugins` in-session, or restart. With `"autoUpdate": true` and a token, both happen at
startup and you are prompted to reload.

## Releasing

There is no version to bump. `plugin.json` omits `version`, so Claude Code falls back to the commit
SHA and **every commit on `main` is the release**. Push and every machine's next update has it.

## Developing

The plugin Claude Code reads is a clone of what you last **pushed**, so editing this working tree
changes nothing in a running session. To try an edit first, add the clone as a second marketplace:

```bash
claude plugin marketplace add ~/Documents/github/deep-thought/deep-thought-skills
```

Two gates, both dependency-free, and both must be clean before a push:

```bash
node scripts/lint-skills.mjs
```

```bash
plugins/deep-thought/skills/dt-skill-creator/scripts/validate-skill.sh --all
```

The linter is the whole-repo check: manifests, frontmatter, that every `${CLAUDE_PLUGIN_ROOT}` path
resolves, that each skill has a command wrapper and a router entry, and that nothing reaches for
`~/.claude/skills`. The validator adds per-skill house-style warnings.

### Paths inside a skill

A skill reaches its own scripts and its siblings through `${CLAUDE_PLUGIN_ROOT}`, which Claude Code
substitutes when it reads the markdown:

```
${CLAUDE_PLUGIN_ROOT}/skills/<name>/scripts/<script>.sh
```

**Shell scripts cannot rely on that variable.** It is a markdown substitution, not something the shell
is guaranteed to have, so a script that needs its siblings resolves the tree from its own location:

```bash
SKILLS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
```

Commit the executable bit (`git update-index --chmod=+x`), or the script arrives non-executable on the
next machine and the skill fails at its first command.
