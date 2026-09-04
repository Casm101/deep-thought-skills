---
name: dt-auto-improve-skill
description: Fold a lesson from the run that just happened back into the skill that should have known it. Judges whether the interaction taught anything general, actionable and new, finds where in the skill it belongs, drafts the edit, and applies it only after you approve the diff. One lesson, one skill, one run, and most runs correctly produce nothing. Use at the end of a skill run, or when asked for "dt auto improve skill".
argument-hint: "which skill, and what it should have known"
---

# dt-auto-improve-skill

A skill run just went slightly wrong, or slightly better than the skill deserved. This is how that
gets written down in the skill rather than lost.

Two facts set the tone. **Most runs teach nothing worth recording**, and reporting "nothing to learn"
is the correct and most common outcome. And **an edit here changes every future session**, so the
asymmetry is brutal: a missed improvement costs one better run, a wrong self-edit costs every run
after it until somebody notices.

So the bar is high and you never apply an edit without approval.

## What this is not for

**A lesson about the world goes to memory, not into a skill.** How this codebase works, what a
library does, what the user prefers, what a person decided. That is what the memory system and
`dt-memory` are for.

This skill only changes **how a skill behaves**. If the lesson does not translate into a phase, a
rule or a prohibition, it is not this skill's business.

## Phase 1. State the candidate lesson

In one sentence, what should the skill have done differently.

Then say where it came from. A specific moment in the run, not a general feeling. "The script reported
zero declarations because `grep -c` prints a bare number for one file" is a lesson. "The skill could be
clearer" is not.

If you cannot point at the moment, there is no lesson. Stop and say so.

## Phase 2. Test it against the bar

Three tests, in `references/what-counts.md`, and **all three must pass**:

| Test | Fails when |
|---|---|
| **General** | It is specific to this repo, this ticket, this file, or today |
| **Actionable** | It cannot be stated as something the skill does or refuses to do |
| **New** | A line in that skill already covers it, even loosely |

Any one failing means it does not get written. Report it as a candidate, say which test it failed, and
stop. That report is a useful outcome, not a failure.

Be strict about **new**. Re-read the skill properly, including its references and its never-list.
Restating an existing rule in different words is the most common way these skills rot: two lines that
nearly agree, and a later reader cannot tell which governs.

## Phase 3. Find where it belongs

The lesson goes where the convention says, and `references/conventions.md` holds the conventions this
suite runs on. Placement, briefly:

| The lesson is | It edits |
|---|---|
| A change to what a phase does | That phase |
| A trap, a mechanism, a worked example | The relevant `references/` file |
| A hard prohibition | The never-list |
| A genuinely new activity | A new phase, which is rare |
| A script got something wrong | The script, plus a line saying why if the reason is not obvious |

**Never add a "Lessons learned" section.** That is where this kind of skill goes to die: a growing
appendix nobody reads, disconnected from the phase it should have changed.

Watch the length. A `SKILL.md` past about 150 lines has something in it that belongs in a reference,
and several in this suite are already close. Growing one is a reason to move something out, not a
licence to keep appending.

## Phase 4. Start from a clean tree

The skills live in the `deep-thought-skills` repository, so **git is the snapshot and the undo**.
What it cannot do is separate your edit from someone else's half-finished one.

```bash
cd ~/Documents/github/deep-thought/deep-thought-skills
git status --porcelain plugins/deep-thought/skills/<skill>
```

Anything already modified there stops the run. Say what is uncommitted and ask what to do with it.
Never fold your edit into changes you did not make.

## Phase 5. Draft the edit

Edit the skill in the repository, at `plugins/deep-thought/skills/<skill>/`. That is the only copy.
The plugin cache Claude Code reads from is a clone of what you last pushed, so nothing you write here
takes effect until Phase 7.

Write it in the skill's own voice, which is the house style in `references/conventions.md`. An edit
that reads differently from its surroundings announces itself as bolted on, and the next reader trusts
it less.

Prefer changing an existing line over adding one. A rule made more precise beats a second rule beside
the first.

## Phase 6. Show the diff and wait

```bash
git -C ~/Documents/github/deep-thought/deep-thought-skills diff -- plugins/deep-thought/skills/<skill>
```

Present four things and stop:

1. The lesson, in one sentence.
2. The moment in the run that produced it.
3. Which skill and which part of it this touches.
4. The diff, in full.

Then wait. **No edit is applied without approval of that specific diff.** Approval of an earlier
improvement is not approval of this one.

If the user says no, discard the edit with `git checkout --` on that path and say the lesson was
rejected. Do not argue for it.

## Phase 7. Validate, commit, push

After approval, check the edit before it leaves the machine:

```bash
R=~/Documents/github/deep-thought/deep-thought-skills
chmod +x "$R"/plugins/deep-thought/skills/<skill>/scripts/*.sh 2>/dev/null
"$R"/plugins/deep-thought/skills/dt-skill-creator/scripts/validate-skill.sh <skill>
"$R"/plugins/deep-thought/skills/dt-skill-creator/scripts/validate-skill.sh --all
node "$R"/scripts/lint-skills.mjs
```

Run `--all` as well as the one skill. An edit to a shared reference or a cross-skill mention has
broken a sibling before.

Any failure means `git checkout --` on that path and start again.

Then commit and push. **Every commit on `main` is the release**, so an unpushed edit changes nothing
anywhere, including on this machine:

```bash
git -C "$R" add -A plugins/deep-thought/skills/<skill>
git -C "$R" commit -m "<skill>: <the lesson in one line>"
git -C "$R" push
```

The running session keeps the old version until the plugin updates. Say so rather than letting the
user assume the next run has the fix:

```bash
claude plugin update deep-thought@deep-thought-skills
```

## Phase 8. Report

The lesson, where it landed, the diff summary, what the validator said, the commit, and that the fix
reaches a session only after a plugin update and a reload.

Then stop. One lesson, one skill, one run. If the interaction taught a second thing, that is a second
run and a second approval.

## Never

- Apply an edit without approval of that exact diff
- Edit on top of changes somebody else left uncommitted
- Touch more than one skill in a run
- Add a "Lessons learned" or "Notes" section, or an appendix of any kind
- Write a lesson that only restates a rule the skill already has
- Record a lesson about the codebase, a library, or a person. That is memory's job
- Edit `dt-memory`, which is not part of this suite, or `dt-unslop`, whose content is the user's own
  text, without being asked directly
- Add a cross-skill reference to `dt-tailwind-migration-tool`, which is deliberately standalone so it
  can be shared outside this suite
- Grow a `SKILL.md` past about 150 lines rather than moving something into a reference
- Skip the validator, or skip `--all`
- Leave the edit uncommitted, or claim a running session already has it

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.
