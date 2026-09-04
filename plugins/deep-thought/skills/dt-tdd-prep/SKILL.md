---
name: dt-tdd-prep
description: Prepare the tests before a change is written. Takes a dt-investigation report or direct context about something to change, improve, fix, or add, works out which existing behaviour has no test and writes those tests, then writes failing tests for the behaviour the change will introduce. Proves the first set passes and the second set fails for the right reason, and hands over a plan naming which existing tests the implementation will have to update. Writes tests only, never production code. Use when asked for "dt TDD prep" or "deep thought test driven development preparation", or to set up tests before implementing a change.
---

# dt-tdd-prep

Write the tests first. Two sets of them.

One set pins down what the code does today, so a change cannot break it quietly. The other set
describes what the code should do after the change, and fails until someone builds it.

## What this skill will not do

**It never writes production code.** Not a line, not a small fix, not "while I was there". The whole
value here is that the tests exist before the implementation, written without knowing how the
implementation will cheat.

It also never:

- weakens or deletes an existing test to make a run go green
- marks a test `.skip`, `.todo`, or `xit` to hide a failure
- updates snapshots (`-u`, `--updateSnapshot`, `--update`)
- introduces a testing library, runner, or pattern the repo does not already use
- leaves a new-behaviour test passing. If it passes, it is testing nothing

## Phase 1. Establish the change

You need three things in writing before you touch a test file.

1. **Current behaviour**, precisely. Not "it shows an arrow", but which element renders, with which
   value, under which condition, and where that is decided in the code.
2. **Wanted behaviour**, precisely, in the same terms.
3. **The seam**, the smallest place where those two differ.

Where those come from, in order of preference:

- A **dt-investigation report**, either already in this conversation or one you are handed. Use it.
- **Direct context** from the user: a ticket, a feature request, a described bug, a file, a symbol.
  Read the code it points at until you can write the three things above.
- **Neither is enough.** Run the `dt-investigation` skill first, in its focused mode, aimed at the
  feature. Do not start guessing from a component name.

If you cannot state current behaviour from the code, stop and say so. A test that pins down
behaviour you have not confirmed is worse than no test, because it makes a wrong belief permanent.

## Phase 2. Recon

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-tdd-prep/scripts/test-recon.sh <path or symbol or keywords>
```

Read-only. It prints the target files, which of them have a test beside them and which have none,
tests that mention the target, the nearest package's test scripts and framework, the config and setup
files, the node version the repo expects, the repo's testing documentation, example tests to copy the
house pattern from, and the shared helpers and mocks nearby.

Two of its outputs matter more than the rest. "NO TEST" tells you where the gaps are. "same name
elsewhere" is a warning, not coverage: open that file before believing it covers anything.

If nothing matches your target, it suggests near misses per word. Pick a real file from those, or ask
the user which component they mean. Never invent a name the repo does not contain.

## Phase 3. Learn how this repo tests

Read the testing documentation the recon found, then read two or three example tests next to the
target. You are copying: the imports, the render helper, the query style, the mocking approach, the
file location, the naming of `describe` and `it` strings.

Note what the repo tests through. If its component tests assert on visible output through
testing-library queries, yours do too. If it reaches for a token or a data attribute, do the same.
Matching the local pattern matters more than writing the test you would write elsewhere.

## Phase 4. Sort the behaviour into buckets

Four buckets, defined in `references/test-buckets.md`, which also works the odds-arrow example
through end to end.

| Bucket | What it holds | Colour now | Colour after |
|---|---|---|---|
| A. Guards | Existing behaviour that must survive the change, and has no test | green | green |
| B. New behaviour | What the change introduces | red | green |
| C. Will need updating | Existing tests that assert the behaviour being changed | green | fail until updated |
| D. Already covered | Existing behaviour with a test that is good enough | green | green |

Bucket C is a list, not work. Do not rewrite those tests to expect the new behaviour, and do not
delete them. The implementation updates them, and that edit is exactly where a reviewer should see
the behaviour change.

Every bucket A and B item names a behaviour someone could observe, not a function you would call.

## Phase 5. The plan, then approval

Write the plan in the format in `references/test-plan-format.md`. Then run the `dt-unslop` skill over
it, along with every `describe` and `it` string you intend to use, since those strings are what a
failing CI run shows a human. Invoke it with the Skill tool as `dt-unslop`, or read
`${CLAUDE_PLUGIN_ROOT}/skills/dt-unslop/SKILL.md` and apply its rules. Leave code, paths, and identifiers alone.

Present the plan and stop. The plan is cheap to redirect now and expensive to redirect once files
exist, which is why the gate is here rather than after writing.

The user can drop items, add cases, or tell you to write them all. If they say to skip the gate and
just write, do that.

## Phase 6. Write the tests

Only after approval, and only buckets A and B.

- New files where the repo would put them, named the way the repo names them.
- Add to an existing test file only when the repo's pattern clearly puts these cases there. Add
  cases, never rewrite what is already there.
- One behaviour per test. A test that needs "and" in its name is usually two tests.
- No conditional assertions, no assertions inside loops that could pass zero times, no test that
  passes when the thing it renders is absent.
- Bucket B tests assert the wanted behaviour as if it already worked. Write no `TODO`, no commented
  out expectation, no placeholder.

## Phase 7. Prove the colours

Run the tests and check each set is the colour it should be, using
`references/running-tests.md` for the mechanics and the traps.

- **Bucket A must pass.** A red guard means you misread current behaviour. Go back to Phase 1, fix
  your understanding, then fix the test. Never adjust the assertion until it goes green without
  knowing why.
- **Bucket B must fail, for the right reason.** Read the failure. It has to be the assertion that
  fails, showing the current value against the wanted one. An import error, a typo, a missing mock,
  or a render crash is a broken test, not a red test, and it proves nothing.

Report the real output, including counts. If you could not run the suite, say that plainly and say
why, rather than implying the colours are confirmed.

## Phase 8. Hand over

Close with a short note the implementer can work from:

1. What to build, in one or two sentences, pointing at the seam from Phase 1.
2. Which tests turn green when it works, by file and name.
3. Bucket C, the existing tests whose expectations the change has to update, by file and line.
4. Anything you could not settle, and what would settle it.

Keep it short. The tests carry the detail now.

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.
