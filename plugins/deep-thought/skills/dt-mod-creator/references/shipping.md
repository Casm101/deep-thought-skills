# Shipping a mod

The marketplace this machine installs from is a git source, so an install copies whatever is on
GitHub `main`. Every commit on `main` is a release. Nothing here runs before the person has said the
mod looks good.

## Commit

```bash
git -C "$R" rev-parse --abbrev-ref HEAD
git -C "$R" fetch origin main
git -C "$R" rev-list --count origin/main..HEAD
git -C "$R" rev-list --count HEAD..origin/main
```

- Both counts must be 0. Commits ahead are someone's other work, and the push would publish them.
  Commits behind mean the branch needs bringing level first. Either way, stop and ask.
- The branch may be `main` or a desktop worktree's own `claude/...` branch. Both work, as long as
  the counts are 0. Never trust the branch from the conversation's opening snapshot.

Run the repo's lint, then stage the mod's paths by name and nothing else:

```bash
node "$R"/scripts/lint-skills.mjs
git -C "$R" add mods/<name> .claude-plugin/marketplace.json .gitignore
git -C "$R" diff --cached --stat
```

Read the staged list. A path outside those three means something else was staged. Unstage it.

The commit message follows the repo: `Add <name>: <what it does, in a few words>`, a short body
saying where it shows and how to drive it, and the attribution line the session asks for.

## Push

```bash
ssh-add -l
git -C "$R" push origin HEAD:main
git -C "$R" fetch origin main
git -C "$R" rev-parse HEAD origin/main
```

- `ssh-add -l` saying the agent has no identities means the passphrase-protected key is not loaded.
  Stop and ask the person to run `ssh-add ~/.ssh/id_ed25519`. Never enter the passphrase, never
  switch the remote to HTTPS, never run `gh auth setup-git`.
- The two hashes must match after the push. "Everything up-to-date" right after a new commit means
  the push went to a different ref than the commit.
- A rejected push means `main` moved. Never force. Fetch, and if the mod's commit no longer
  fast-forwards, stop and ask.

## Install

`/plugin install` is not available in the desktop Code tab, so install through the CLI:

```bash
"$CLAUDE_CODE_EXECPATH" plugin marketplace update deep-thought-skills
"$CLAUDE_CODE_EXECPATH" plugin install <name>@deep-thought-skills --scope user
```

Fall back to `claude` when `CLAUDE_CODE_EXECPATH` is unset. User scope loads it in every session,
terminal and desktop alike, and touches no project's settings. A mod that only makes sense in one
repository checks the working directory itself and stays quiet elsewhere.

Then, before the reload, the hot-reloaded dev copy has to go, or this session runs it twice, as
`<name>@inline` and `<name>@deep-thought-skills`. The fence keeps the skill out of that folder, so
the person runs:

```bash
rm ~/.claude/dev-mods/$CLAUDE_CODE_SESSION_ID/<name>
```

That removes the link only. Then they type `/reload-plugins`, which re-reads installed plugins in
the desktop Code tab as in a terminal. New sessions pick the mod up on their own.

## What other people run

```
/plugin install <name> --marketplace Casm101/deep-thought-skills
```

in a terminal session, answering `y` to add the marketplace and Enter for user scope. The repository
is private, so only people with access to it can install from it.

## A terminal older than mods

Mods arrived in Claude Code 2.1.287. The desktop app runs its own build, but a terminal runs whatever
`claude` is on `PATH`. When the preflight warned that build is older, say so in the hand back with the
command the person would run, `brew upgrade claude-code`, and leave running it to them.
