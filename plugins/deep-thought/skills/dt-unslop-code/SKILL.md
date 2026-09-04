---
name: dt-unslop-code
description: Strip the unnecessary comments a change left behind, and clean the slop out of the ones worth keeping. Works on the comments the change itself added or touched, deletes process history, ticket ids, third-party links and anything that restates the code, keeps a comment only where it states a constraint the code cannot, and applies the dt-unslop rules to whatever survives. Comments only, never logic. Use when asked for "dt unslop code", or to clean up or remove comments after a change.
---

# dt-unslop-code

Most comments a change leaves behind are noise. Delete them.

`dt-unslop` does this for prose. This does it for source, where the failure mode is worse: a comment
that restates the line above it never goes stale in a way anyone notices, so it lives forever and the
next reader has to check whether it is still true.

## The rule

**A comment earns its place by saying something the code cannot.** Everything else goes.

That is a high bar, and it is meant to be. The test is not "is this comment true" or "is this comment
harmless", it is "would a competent reader of this code be missing something without it".

## Scope

**Only comments on lines this change added or modified.** Pre-existing comments elsewhere in a touched
file are left alone, however bad they are. Cleaning them makes a feature change into a comment
refactor, and reviewers then have to read both.

If you see something egregious outside that boundary, mention it to the user and leave it.

**In scope:** comments, docblocks on lines you touched, commented-out code, debug logging this change
added, and test `describe` and `it` descriptions.

**Out of scope:** variable and function names, dead code that is not commented out, and anything about
how the code works. Renaming things during a comment cleanup is how a small change becomes
unreviewable.

## Phase 1. Find the candidates

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-unslop-code/scripts/comment-diff.sh [<base ref>]
```

No argument covers uncommitted work, which is the usual case when this runs inside `dt-implement`.
Pass a base ref such as `origin/main` to cover everything on the branch.

It prints every added or modified comment line with its file and line number, marks lines that are
code with a trailing comment, and skips prose files and generated output. A regex or a URL is
occasionally flagged; that costs a glance, and the alternative is missing real slop.

## Phase 2. Triage every candidate

Judge each one against `references/comment-rules.md`, which has the keep and delete categories with
examples of both.

The short version. Delete a comment that carries process history, a ticket id, a third-party link,
a restatement of the code, or a banner. Keep one that states a constraint, an ordering requirement, a
workaround, or a unit that the code does not make obvious.

Where a comment is half worth keeping, rewrite it to the half that is. Most surviving comments end up
shorter than they started.

## Phase 3. Unslop what survives

Run `dt-unslop` over the text of every comment you kept. Comment prose is prose, and it carries the
same tells: em dashes, hedging, the rule of three, restating the point twice, adjectives doing a
verb's job.

Two rules on top of the usual ones. Comments are short, so a surviving comment is one or two lines
unless it genuinely needs more. And write the constraint, not the story: "the API is 1-indexed" beats
"note that we discovered the API returns 1-indexed positions".

## Phase 4. Edit

Make the deletions and rewrites.

Three of the in-scope items are code rather than comments, and they need care:

- **Commented-out code** is a comment. Delete it. Git remembers it.
- **Debug logging this change added** is a code change. Delete it, and only what this change added.
  A `console.log` that was already there is out of scope.
- **A test description** is a code change. Reword it freely, with one exception: if that test has a
  snapshot keyed on its name, leave the name alone. Renaming it orphans the snapshot, and this skill
  never updates snapshots.

Never touch logic, control flow, types, or anything a test could notice, beyond those three.

## Phase 5. Verify and report

Because Phase 4 can touch code, prove it did not break anything:

- the type check for each package you touched
- the tests for the files you touched

Both should pass exactly as they did before. If either moved, you changed something you should not
have. Revert that edit rather than fixing the test.

Then report: how many comments you deleted, how many you rewrote, how many you kept and why the kept
ones earned it. Name the ones you left outside the boundary, if any.

Keep the report short. A long report about deleting comments is its own kind of slop.

## Never

- Touch a comment outside the lines this change added or modified
- Change logic, control flow, types, or names
- Delete a comment that states a constraint the code does not, however wordy it is. Rewrite it
- Keep a comment because deleting it feels destructive. Git has it
- Update a snapshot, or rename a test whose snapshot is keyed on its name
- Add a comment. This skill removes and rewrites, it does not author
- Explain in a comment why the comment is short

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.
