---
name: dt-implement
description: Build a piece of work from a spec, a set of tickets, or context handed straight to you. Gets the tests in place with dt-tdd-prep first, then implements in small slices, running type checks and the one relevant test file after each, the whole suite once at the end. Reviews the finished work with dt-code-review, then commits to the current branch. The only dt skill that writes code. Use when asked for "dt implement", or to build, implement, or do the work for a spec or ticket.
---

# dt-implement

Build the thing. Tests first, small slices, checks after every slice, one review, one commit.

This is the only skill in the family that writes code. Everything it does to the repository stays on
the current branch and stops at the commit.

## Before the first line of code

You need three things. Get them from the spec, the tickets, or what you were told.

1. **What done means**, in behaviour someone could check.
2. **The scope boundary**, what this work does not include.
3. **Where the seam is**, the place the change actually goes.

If any of those is missing, the answer is not to start writing and find out.

- Open design decisions nobody has made, run `dt-grilling` first.
- Too big for one pass, run `dt-to-tasks` and implement one task from the result.
- You do not understand the code yet, run `dt-investigation`.

Say which of these you skipped and why, so the record shows it was a decision.

Then check where you are:

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-implement/scripts/impl-loop.sh
```

It prints the branch, warns if it is the default one, checks the node version against `.nvmrc`, lists
what you have changed, lists untracked files you must not stage, maps each changed file to its test,
and prints the exact type-check, single-test, whole-suite and lint commands for the packages
involved.

**Never write code on the default branch.** If the script says you are on it, stop and branch.

## Tests first

Run `dt-tdd-prep` wherever it applies. It leaves you with guard tests that pass, tests for the new
behaviour that fail, and a note of which existing tests the change has to update.

That gives the loop below something to aim at: make the red ones green, keep the green ones green.

Where it does not apply, say so plainly and say why. A config change, a dependency bump, or a
generated file may have nothing to test. "It was quicker without" is not a reason.

If tests already exist for this work, run them first and write down the colours before you touch
anything. You cannot tell what you broke if you never saw it working.

## The loop

Smallest slice that moves one acceptance criterion, then check, then the next.
`references/loop.md` has the detail, including what each colour means and when to stop and think.

After every slice:

- the type check for the package you touched
- the one test file that covers what you just changed

Not the whole suite. It is slow, and a full run after a three line change tells you almost nothing
you did not already know.

Two rules that hold for the whole loop. **Never weaken a test to get green**, and **never touch a
guard test**. A guard going red means you broke something the change was supposed to leave alone, and
that is the most valuable signal you will get all session.

## Clean the comments

Once the loop is green and before the gate, run `dt-unslop-code`. It removes the comments the work
left behind, keeps only the ones stating something the code cannot, and cleans the slop out of those.

It goes here rather than after the gate on purpose. It can touch a little code, debug logging it
added and test descriptions, so running it first means the whole suite below covers the cleanup too.

## The gate at the end

Once every acceptance criterion is met, and only then:

1. The whole test suite, once, for each package you touched.
2. The lint and format checks the repo runs in CI.

Fix what these turn up, then run them again. If something still fails and you cannot fix it, stop.
Say what fails and what you tried. Do not commit a red suite, and do not reach for `--no-verify`.

## The review

Run `dt-code-review` on the work. It sends the diff to an agent with none of this session's context,
so it reads your change the way the next person will, without your reasoning to lean on.

Then act on what comes back:

- A blocker gets fixed, and the loop's checks run again.
- Anything you disagree with, say so and say why, in the report. Do not silently drop it.
- Out of scope findings get written down for later, not fixed here.

If the review changes the code, run the whole suite again before committing.

## The commit

Follow `references/committing.md`. In short: stage by path, never with `-A` or `.`, write the message
the way this repo writes them, commit to the current branch, and stop there.

No push, no PR, no merge, no branch switching. Once the commit exists, this skill is finished. Opening
the PR is yours, and `dt-pr-data` fills in its description afterwards.

## Scope

Implement what was specified and nothing else. When you spot a real problem outside the boundary,
write it down in your closing summary and leave the code alone. A change nobody asked for is a change
nobody reviewed with that in mind.

Closing summary, short: what you built, what the final suite said, what the review found, what you
committed, and anything you noticed and deliberately left.

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.
