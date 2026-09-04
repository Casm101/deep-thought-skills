# The bar, and where a lesson lands

## The three tests

All three, or it does not get written.

### General

It will happen again, in another repo or another ticket or to another person.

```
passes  grep -c prints a bare number for one file and file:count for several, so summing
        field 2 with awk silently reports zero
passes  a fresh git worktree has no working package links, so tests there need an install first
fails   the branch was called bugfix/TS-42830-my-bets-x-cast-combinations
fails   this ticket's acceptance criteria were vague
```

The second pair are facts about one moment. Useful in a handoff, useless in a skill.

### Actionable

You can state it as something the skill does, checks, or refuses to do. If the only way to write it is
as advice, it is not a rule.

```
passes  after any block edit, read the section back, because a replacement that appends instead
        of substituting leaves the old block in place
fails   be careful when editing
fails   the skill should be smarter about context
```

A rule a reader could follow without judgement is actionable. "Be careful" is not.

### New

No line in that skill already covers it, in any of its files, however loosely.

This is the test that gets skipped, and skipping it is how these skills rot. Two rules that nearly
agree are worse than one, because a later reader cannot tell which governs and will follow whichever
they read first.

Re-read the skill properly before claiming novelty. The `SKILL.md`, every reference, and the
never-list. Then ask whether the existing line would have prevented the problem if somebody had
followed it. If it would, the lesson is not new: the lesson is that the line was not prominent enough,
which is a different and usually smaller edit.

## Where it lands

| The lesson is about | It edits | Because |
|---|---|---|
| What a phase does or checks | That phase | The rule belongs where the work happens |
| A trap, a mechanism, an example | The relevant reference | Detail belongs out of the main flow |
| Something never to do | The never-list | Prohibitions are read as a set |
| A whole activity nobody thought of | A new phase | Rare, and usually means the skill was wrong about its scope |
| A script's behaviour | The script, and a comment if the reason is not obvious from the code | The script is the enforcement |

Two placements that are always wrong.

**A "Lessons learned" section.** It grows, nobody reads it, and it sits disconnected from the phase it
should have changed. If a lesson cannot find a home in the existing structure, that is a signal the
lesson is vague, not that the skill needs an appendix.

**The description.** The frontmatter description is a trigger, not documentation. A lesson never
belongs there unless the lesson is literally that the skill triggers at the wrong time.

## Prefer editing over adding

The best edit makes an existing line more precise. The second best adds a line. Adding a whole section
is a last resort.

```
before  Read the surrounding file, not just the diff hunk.
after   Read the surrounding file, not just the diff hunk. A guard clause one level up settles half
        of all review disputes.
```

One line, more useful, nothing longer to read.

## When the lesson contradicts the skill

Sometimes the run showed an existing rule to be wrong, not incomplete. That is a real and valuable
finding, and it needs saying out loud rather than quietly editing.

Say which rule, why the run contradicts it, and what you propose instead. Never delete a rule silently.
Somebody put it there for a reason and that reason may still hold in a case you have not seen.

## Worked example, pass

The run: a script reported zero CSS declarations for a file that had 22.

The lesson: `grep -c` prints a bare count for one file and `file:count` for several, so parsing with
`awk -F:` and summing field 2 gives zero on the single-file case.

General, it will happen in any script counting matches. Actionable, it is a rule about how to count.
New, nothing in the skill mentioned it. It lands in the script's own comment and in the conventions
note about testing scripts against real data.

## Worked example, fail

The run: the user preferred a shorter report than the skill produced.

Tempting, and it fails **general**. One person's preference in one moment, on one report. If the same
note comes back three times across different runs, it has become general and is worth revisiting then.

A single preference belongs in memory, where it can be recorded as a preference rather than promoted
into a rule everyone inherits.
