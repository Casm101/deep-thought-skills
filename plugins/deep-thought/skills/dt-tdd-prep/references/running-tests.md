# Running the tests, and reading the colours

The point of this phase is evidence. Two sets of tests, each the colour it should be, proven by real
output rather than by reasoning about what should happen.

## Get the runner right first

The recon script prints the nearest package's test scripts. Run from that package, not the repo root,
because config, setup files and path aliases are usually per package.

```bash
cd <package dir>
pnpm test --run <path to the test file>            # one file
pnpm test --run <path> --reporter=verbose          # see individual case names
pnpm test --run <path> -t "renders a down arrow"   # one case by name
```

Match the repo's own invocation. If the script carries a prefix such as `TZ=Europe/Berlin`, keep it.
Dropping it changes results in any test that touches dates.

**Check the node version before you blame your test.** The recon prints `.nvmrc` and `engines`. A
suite run on the wrong major version fails in ways that have nothing to do with what you wrote. If the
shell's node does not match, switch it the way the repo expects (usually `nvm use`) and say so in the
report if you could not.

Run the narrowest thing that answers the question. A single file first, the neighbouring files after,
and the whole suite only if the change reaches widely.

## Never do these while running

- `-u`, `--updateSnapshot`, `--update`. Writing a snapshot to make a test pass records whatever the
  code currently does as correct, which is the opposite of the job.
- `--reporter=dot` when you need to read a failure. You need the assertion text.
- Passing `--bail` while checking bucket B, which hides how many of your red tests are red.
- Editing an assertion because the run was red, before you understand why it was red.

## Reading bucket A, the guards

Expected: all green.

A red guard is information, and it is usually about you rather than the code. In order of likelihood:

1. You misread current behaviour. The arrow does not do what you thought. Go back to Phase 1.
2. Your setup is wrong: a missing provider, an unmocked dependency, a timer you did not advance.
3. The behaviour is genuinely broken today, and you have found a live bug. Say so clearly, and do not
   quietly pin the broken behaviour as correct.

The one thing you may not do is loosen the assertion until it passes. That produces a test that
guards nothing.

## Reading bucket B, the new behaviour

Expected: all red, each for the reason you predicted in the plan.

A red test proves nothing on its own. Read the output and check the failure is the assertion:

- **Right kind of red.** `expected "blue" to be "green"`, a value mismatch, a missing element that
  the change will add. The test ran, rendered, and disagreed.
- **Wrong kind of red.** Import error, type error, `undefined is not a function`, render crash,
  missing mock, a typo in a query. The test never got as far as the behaviour, so it is broken, not
  pending. Fix it and rerun.
- **Green.** Something is wrong. Either the behaviour already exists, in which case say so and stop,
  or the assertion is too loose to distinguish old from new. Tighten it.

Quote the actual failure line for each bucket B test in your report. That quote is the proof that the
test will pass for the right reason later.

## What to report

```
Guards      6 written, 6 passing
            AnimatedOddsValue.spec.tsx  6 passed  (1.4s)

New         2 written, 2 failing as intended
            B1  expected token "colour.trend.up.blue", received "colour.trend.up.green"
            B2  expected token "colour.trend.down.yellow", received "colour.trend.down.red"

Suite       AnimatedOddsValue.spec.tsx and the two neighbouring specs run clean apart from B1 and B2
Node        24.10.0, matches .nvmrc
```

If a run was impossible, say which command you tried, what it printed, and what would unblock it. An
unproven colour is not a colour.
