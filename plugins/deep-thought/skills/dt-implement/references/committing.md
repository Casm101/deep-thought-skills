# Committing

The last thing this skill does. Everything below is about not committing something nobody asked for.

## Before you stage

**Check the branch.** `git rev-parse --abbrev-ref HEAD`. If it is `main`, `master`, or whatever
`origin/HEAD` points at, stop. Never commit to the default branch, and say so rather than branching
on your own initiative unless the user already asked for a branch.

**Look at what is actually different.** `git status --porcelain` and `git diff`. Read it. This is the
last point where a stray debug line, a commented out block, or a file you opened and saved by accident
is cheap to remove.

**Check the untracked list.** `impl-loop.sh` prints it, and so does `git status`. In a repo with tool
directories or local config sitting untracked, `git add -A` quietly commits somebody's editor settings.

## Staging

**By path, always.**

```bash
git add path/to/one/file.ts path/to/another.spec.ts
```

Never `git add -A`, never `git add .`, never `git add -u` in a repo you did not check first. Stage the
files you changed for this work, and nothing else.

Then read the staged diff before committing: `git diff --cached`. What you are about to commit is
exactly this, and no more.

## The message

Match the repo. Read `git log --oneline -20` and copy what you see.

Most repos want a ticket key and an imperative summary in the subject line:

```
TS-42830 Show the settled finishing order on a combination tricast
```

Rules that hold whatever the local style is. The subject says what the change does, not what you did
to the code. Present tense, imperative. Under about seventy characters. No trailing full stop. A body
only when the why is not obvious from the subject, wrapped at seventy-two, saying why rather than
what, because the diff already says what.

No trailers. This team does not use `Co-Authored-By` or any other trailer, so the message is the
subject line and, when it earns one, a body.

## How many commits

One per coherent behaviour change. If the work covered three tickets or three slices, three commits,
each one green on its own. If it was one change, one commit.

Do not split a single change into "add the file" and "make it work". Do not lump three unrelated
behaviours into one commit because they happened in the same session.

## Committing

```bash
git commit -m "TS-42830 Show the settled finishing order on a combination tricast"
```

**Never `--no-verify`.** The hooks are the team's gate, and skipping them moves your failure into
somebody else's CI run. If a hook blocks the commit, the hook is the message: fix what it found.

If the hook rewrites files, for example a formatter, check what it did with `git diff`, stage that too,
and commit again.

## After the commit

Stop. Report the hash and the subject line.

Never do any of these without a fresh, explicit ask:

- `git push`
- Opening a PR
- `git merge`, `git rebase`, `git reset --hard`, `git checkout` to another branch
- Amending or rewriting a commit that already exists
- Touching a stash you did not create
