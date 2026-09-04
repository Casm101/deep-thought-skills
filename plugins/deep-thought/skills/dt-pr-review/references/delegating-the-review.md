# Delegating the review

The reviewing is done by `dt-code-review` or `dt-overkill-code-review`. This file is how you pick one,
how you make sure it reads the right code, and how its findings become comments.

## Which reviewer

The resolver computes it. Take its answer unless the user overrode it.

`dt-overkill-code-review` if **any** of these is true:

| Signal | Threshold |
|---|---|
| Changed lines | more than 400 |
| Changed files | more than 15 |
| Workspace members touched | more than 3 |
| Sensitive paths | any, meaning money, identity, access control, sessions, secrets or migrations |
| Labels | any of migration, refactor, breaking, release, hotfix |

Otherwise `dt-code-review`.

The thresholds are deliberately blunt. A rule you can compute beats a judgement call about whether a
PR "feels big", and it means two people reviewing the same PR get the same depth.

Overrides are fine and come from the user, never from you. "This looks tricky, I will run the three
model one" is a judgement call the thresholds exist to remove. Report which reviewer ran and why in
every case, including when the user overrode.

## Make sure it reads the PR's code

The reviewing agents read files from the working tree. If the checkout is not the PR's head, they read
the base version of every file the diff touches, which is worse than useless: the diff says one thing
and the surrounding code says another.

Check first:

```bash
git rev-parse HEAD                                   # what is checked out
gh pr view <n> --repo <owner>/<repo> --json headRefOid -q .headRefOid
```

**They match.** Delegate straight away.

**They do not match, and the working tree is clean.** Check the PR out, review, then go back:

```bash
git status --porcelain          # must be empty of tracked changes
gh pr checkout <n> --repo <owner>/<repo>
# ... run the delegated review ...
git switch -                   # back where you started
```

Say in the report that you checked the PR out and returned. It is a change to the user's working
state, small and reversible, but they should hear it from you.

**They do not match and the tree is dirty.** Do not check anything out. Say what is uncommitted, and
offer the choice: commit or stash first, or accept a diff-only review.

**A diff-only review** is the fallback, not the default. The agents get the diff and the docs and no
working tree at the right commit, so they cannot follow a caller or check a type. Label every finding
from such a review as diff-only in the report, and expect fewer of them.

## Send the checklist as an addendum

Append `references/review-checklist.md` to the agent brief, under a heading saying these are
additional axes to cover. It keeps a PR review as broad as it was before delegation, without changing
the report format the agents return.

Change nothing else about the brief. The packet, the read-only instruction and the required output
shape stay exactly as the delegated skill defines them.

## Severity mapping

The agents report on their scale. Comments go out on this one. The mapping is fixed so that a blocker
means the same thing whichever reviewer ran.

| Agent severity | Comment severity | Note |
|---|---|---|
| `blocker` | **blocker** | Bug, data loss, security issue, or a broken documented rule |
| `should-fix` | **should-fix** | Real quality or maintainability problem |
| `missing-detail` | **should-fix** | A gap in the change is a change the author would expect to make |
| `nit` | **nit** | Style or preference, and the comment must say it is non-blocking |

One rule produces the fourth kind. **A finding whose `fix` is "unclear" and whose confidence is low
becomes a question**, phrased as one. An agent that cannot say what should change has found something
worth raising and not something worth asserting.

Never move a severity for any other reason. Not because a blocker looks overstated to you, and not
because a nit looks important. If a finding is wrong, drop it and say so; if it is right, post it at
the severity it came with.

## What the tally means for the comment

From `dt-overkill-code-review` every finding carries a tally and the models that raised it.

- **Confirmed and majority findings** get posted normally. Do not mention the tally in the comment
  itself. "Two of three models agreed" is process talk and it belongs in your report to the user, not
  on somebody's PR.
- **Minority findings** are not posted unless the user picks them out at the approval gate. One model
  in three is exactly the confidence level that makes a public comment a coin toss.
- **Conflicts** are never posted. Put both claims in the report and let the user decide.

From `dt-code-review` every finding is single source. Post them, and say once in your report to the
user that nothing was cross-checked, so they can weigh the list before approving it.
