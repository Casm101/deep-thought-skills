---
name: dt-skill-creator
description: Build a new dt skill from an idea. Grills the user on how it should work, sketches it, runs the sketch through dt-unslop, decides which other dt skills it should call and where, installs it, wires it into the router, validates it, and prints the markdown for review. Only a person invokes this.
argument-hint: "What should the new skill do?"
disable-model-invocation: true
---

# dt-skill-creator

Turn an idea into a working dt skill, in the shape the rest of the family already has.

**A person invokes this, never an agent.** The frontmatter carries
`disable-model-invocation: true` and it stays. Building a skill means committing to the
`deep-thought-skills` repository, which changes how every later session behaves on every machine, and
that is not a decision to delegate.

## Phase 1. Check it does not already exist

Before anything else, list what is installed and read the router's roster:

```bash
for f in ${CLAUDE_PLUGIN_ROOT}/skills/dt-*/SKILL.md; do
  printf '%-26s %s\n' "$(basename "$(dirname "$f")")" "$(sed -n 's/^description: //p' "$f" | cut -c1-90)"
done
```

If something already covers the idea, say so and stop. Two skills doing one job is worse than
neither, because the router has to guess and they drift apart.

If it partly overlaps, say which skill and ask whether the answer is a new skill or a change to that
one. Extending an existing skill is usually the better answer, and it is the one nobody suggests.

## Phase 2. Grill the user

Run `dt-grilling` on the idea. Its rounds are how you get from a sentence to a specification, and its
rule about looking facts up yourself applies here too: read the sibling skills rather than asking how
the family does something.

The questions worth reaching for, beyond whatever the idea raises:

- What does it read, and what does it write? A skill that writes needs a rule for every write.
- Does anything leave the machine, and does that need approval first?
- Which phase can it not recover from, and what does it do when it gets there?
- What must it never do, stated as a list?
- Is there a deterministic part worth a script, and is that script read-only?
- Who invokes it, a person or another skill or both?
- What does it hand back, and to whom?

Stop grilling when you can write the description and the never-list without inventing anything.

## Phase 3. Sketch it

Build the files under `plugins/deep-thought/skills/<name>/` in the repository, following
`references/skill-anatomy.md` for the layout, the frontmatter and what belongs in each file.

Write the `SKILL.md` first and completely. If a phase is hard to write, the design is not settled, and
another grilling round is cheaper than a vague phase.

## Phase 4. Decide what it calls

A skill that reaches for a sibling at the right moment beats one that repeats its work. Wire in only
what it genuinely needs, at a named phase, and say why in the skill's own text.

| Reach for | When the new skill |
|---|---|
| `dt-unslop` | produces any prose a person reads, which is nearly all of them |
| `dt-investigation` | needs to understand code it did not just write |
| `dt-grilling` | has open design decisions it cannot settle from evidence |
| `dt-to-tasks` | faces work too big for one pass |
| `dt-tdd-prep` | is about to change behaviour that has no tests |
| `dt-code-review` or `dt-overkill-code-review` | wants a cold read of a change |
| `dt-handoff` | can stop half way and leave someone to pick it up |

Two rules. **Name the phase**, so "uses dt-unslop" becomes "runs dt-unslop over the draft before
Phase 5 shows it to the user". And **do not chain everything**, because a skill that calls five others
is a workflow wearing a skill's clothes, and the router is what picks between skills.

Write down where each one is called and what happens if it is unavailable.

## Phase 5. Unslop the sketch

Run `dt-unslop` over every file you wrote. Leave code, paths, identifiers and any format template the
user specified alone, including one that breaks a rule because they asked for it.

## Phase 6. Wire, validate, commit

`references/installing.md` has the exact steps and the traps. In order: make the scripts executable,
write the command wrapper, add the skill to the router in **three** places and to the README roster,
then run both checks:

```bash
R=~/Documents/github/deep-thought/deep-thought-skills
"$R"/plugins/deep-thought/skills/dt-skill-creator/scripts/validate-skill.sh <name>
node "$R"/scripts/lint-skills.mjs
```

Fix everything they report before going further. A failure there is a skill that will misbehave on its
first real use.

Then commit and push, because **an unpushed skill exists nowhere**, including in the next session on
this machine. It reaches a session after `claude plugin update deep-thought@deep-thought-skills` and a
reload.

Then update the memory note that tracks the family, so the next session knows the roster changed.

## Phase 7. Print it and stop

Output the full `SKILL.md` in the session, in a fenced block, so the user can read what was installed
without opening a file. Name the reference files beside it rather than pasting them, unless the user
asks.

Then say three things: which other dt skills it calls and where, which decisions you made that they
may want to flip, and that a new session is needed before the skill loads.

Never test the new skill by running it on real work in the same breath. Installing it and using it are
two separate asks.

## Phase 8. Improve it after its first real run

A skill written before it has ever run is a guess about how the work goes. The first real use is where
that guess meets the work.

So when a run of the new skill teaches something general about how it should behave, fold it in with
`dt-auto-improve-skill` rather than remembering it. That skill applies the same conventions this one
does, snapshots before editing, and waits for approval on the diff.

This is not part of creating the skill. It is what happens next, and it is worth saying here because
the moment a skill is installed is exactly when people stop thinking about it.

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.
