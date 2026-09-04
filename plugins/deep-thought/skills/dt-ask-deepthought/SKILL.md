---
name: dt-ask-deepthought
description: Router for the dt skills. Ask it which dt skill fits the situation instead of remembering the whole set. Reads the current context, names the one skill to run now, says why in a line, gives the exact invocation and what it needs as input, and names what comes after it. Answers "none of them" when the work is faster done directly. Use when asked which dt skill to use, which deep thought skill applies, what to run next, or where to start.
---

# dt-ask-deepthought

Pick the one skill that fits what is happening right now. One skill, not a programme of work.

You are answering a question, not doing the job. Name the skill, say why, hand over the invocation.

## The map

Most work runs along one flow. Two on-ramps merge into it. One skill runs underneath everything, and
two stand on their own.

```
MAIN FLOW
  dt-create-branch ──► dt-investigation ──► dt-grilling ──► dt-to-tasks ──► dt-implement ──► dt-ship ──► dt-pr-data ──► merge
  start here if you                          agree the    one task     calls dt-tdd-prep    push and
  are still on main                          design       at a time    first, dt-code-      open the PR
                                                                       review at the end

ON-RAMPS, each merging into the main flow
  dt-pr-review     reviewing someone else's PR. Joins at dt-investigation when the review turns
                   up real work.
  dt-pr-defense    feedback landed on your own PR. Joins at dt-tdd-prep for every point you
                   agreed to fix.

AFTER THE PR IS OPEN
  dt-pr-slack-message  announce a sportsbook-ui PR in #pt-sports-frontend-prs. That repo only.

OPTIONAL ON THE MAIN FLOW, after you implement and before the PR
  dt-code-review            one agent with no session context. The everyday choice.
  dt-overkill-code-review   the same, with three agents on three different models judged
                            against each other, when the change is large or risky.

END TO END, UNATTENDED
  dt-auto-develop  runs the whole main flow from a ticket with no human input, and finishes at an
                   open PR, reporting back every assumption it had to make.

UNDERNEATH
  dt-unslop        runs inside the others, and on any writing at any point.
  dt-unslop-code   the same for source comments, after a change is written.
  dt-auto-improve-skill  after any run, when the run taught the skill something.

STANDALONE
  dt-ticket-refiner   sharpen a Jira ticket until it can be built from. A person invokes it.
  dt-tailwind-migration-tool  move one component from styled-components to Tailwind, proved
                      identical. Self-contained, so it can be shared outside this set.
  dt-storybook-creator  write a component's Storybook story, or explain why it should not have
                      one. Also self-contained and shareable.
  dt-test-account     create a staging test player and hand back its credentials and BO links.
  dt-inherit-branch   pick up a branch somebody else was working on, and know what you hold.
  dt-branch-update    bring a branch up to date with origin's default branch, then push.
  dt-merge-conflicts  a merge, rebase or cherry-pick stopped on conflicts.
  dt-handoff       the session is ending and someone else continues.
  dt-skill-creator builds a new dt skill. A person invokes it, never an agent.
  dt-ask-deepthought   this one.
```

`dt-implement` is the only skill that writes code or commits. Every other one reads, reports, or
posts to GitHub. It runs `dt-tdd-prep` before it starts and `dt-code-review` before it commits, so
reaching for those separately is only worth it when you want just that piece.

## The roster

| Skill | Use it when | It needs | It gives back |
|---|---|---|---|
| `dt-auto-develop` | You want a ticket built with nobody watching, and a PR to review afterwards | A Jira key or a described task | An open PR with the change and its tests, and a log of every assumption it made, reported back to you |
| `dt-create-branch` | The work has nowhere to live yet, usually because you are still on the default branch | A ticket key or a description of the work | A branch off the fetched default, named the way this repo names them |
| `dt-inherit-branch` | You are taking over work somebody else started | The branch, or nothing for the current one | A briefing on where it stands and how complete it is, plus a memory of what nobody could reconstruct |
| `dt-tailwind-migration-tool` | A component needs moving from styled-components to Tailwind | A component name or path | The component migrated, or a refusal naming the blocker, with every CSS declaration accounted for |
| `dt-storybook-creator` | A component may need a Storybook story | A component name or path | The story written and looked at, or a refusal naming the rule that says it should not have one |
| `dt-test-account` | You need a test player on staging | A brand and country, or a staging URL | The account created and verified, with its credentials and three backoffice links |
| `dt-branch-update` | A branch has fallen behind the default branch | The branch, or nothing for the current one | The merge committed, verified and pushed, or a refusal if the branch is a release branch |
| `dt-merge-conflicts` | A merge, rebase or cherry-pick is sitting on conflicts | The repo mid-operation | Both sides' intentions kept, both sides' tests passing, the operation completed |
| `dt-investigation` | You do not yet understand the code well enough to change it, or someone asked how something works | A topic, path, symbol, or nothing at all | A written report, changes nothing on disk |
| `dt-grilling` | The design has open decisions nobody has made, and you would be guessing if you started | Whatever is known so far | A decision tree, agreed round by round, nothing left assumed |
| `dt-to-tasks` | The work is understood but too big for one go, and needs breaking into tasks | The conversation, an issue reference, the code | Vertical tasks with blocking edges, in pick-up order |
| `dt-ticket-refiner` | A ticket is too thin to build from | A ticket key, URL, or the current branch | The definition, requirements and criteria rewritten onto the ticket, with the reporter's words kept |
| `dt-tdd-prep` | You know what to change and no tests exist yet for the old or the new behaviour | An investigation report or direct context | Passing guard tests, failing tests for the new behaviour, a plan |
| `dt-implement` | The work is understood and you want it built, tested, reviewed and committed | A spec, tickets, or direct context | The code, a green suite, a cold review, and a commit on this branch |
| `dt-ship` | The work is committed and needs to go up for review | The branch | The branch pushed and a PR opened against the right base |
| `dt-pr-data` | A PR exists and its description is empty, stale, or full of template placeholders | The PR, found from the branch or given | An updated description, plus the fields only a human can fill |
| `dt-pr-slack-message` | A sportsbook-ui PR is open and the team should hear about it | The PR, and anyone specific to cc | One line posted to #pt-sports-frontend-prs, after you approve it |
| `dt-pr-review` | You are reviewing a pull request, usually someone else's | A PR number, branch, or URL | Findings for approval, then inline comments posted with gh. Delegates the reviewing itself to `dt-code-review` or `dt-overkill-code-review` by PR size |
| `dt-pr-defense` | Review feedback landed on your own PR and you need to answer it | Your PR | A work item per agreed fix, drafted replies for the rest |
| `dt-code-review` | You want the branch reviewed by someone without this session's context, which is most of the time | The branch, and the repo's own docs | One cold review, reported as single source |
| `dt-overkill-code-review` | A change on the branch is large or risky and one review is not enough | The branch, and the repo's own docs | Three reviews on three different models, judged against each other, with a tally per finding |
| `dt-unslop` | Any writing is about to reach a human | The text | The same text without the AI tells |
| `dt-unslop-code` | A change is written and left comments behind | The change | The unnecessary comments gone, the rest shortened to what the code cannot say |
| `dt-auto-improve-skill` | A run showed a skill should have known something | The lesson, and which skill | The skill edited to carry it, after you approve the diff |
| `dt-handoff` | The session is ending, or context is running out, and the work continues elsewhere | The conversation | A handoff document in the temp directory |
| `dt-skill-creator` | The user wants a new dt skill built | An idea for one | The skill installed, wired into this router, and printed for review |

## How to choose

Work down this list and stop at the first match. Order matters, because several will look plausible
at once.

1. **Does the user want a whole ticket built unattended?** `dt-auto-develop`. Say what it gives back,
   an open PR plus a log of every assumption it made, and that nobody will have reviewed the design
   or the tests along the way. It is the only skill that runs the others on its own.
2. **Is the user taking over work they did not start?** `dt-inherit-branch`, before anything else
   touches the code. It is also the right answer when they have simply forgotten where a branch got to.
3. **Has a branch fallen behind the default branch?** `dt-branch-update`. It refuses on release and
   hotfix branches, where CI forbids the merge, and hands any conflicts to `dt-merge-conflicts`.
4. **Is a merge, rebase or cherry-pick stopped on conflicts?** `dt-merge-conflicts`. Nothing else
   can run usefully until the tree is resolved.
5. **Is the user on the default branch with work to start?** `dt-create-branch` first. Nothing else
   should write code from there.
6. **Is the work committed and needing to go up?** `dt-ship`, to push and open the PR. It hands the
   description to `dt-pr-data` straight after.
7. **Does an open sportsbook-ui PR need announcing to the team?** `dt-pr-slack-message`. Only in that
   repo, and it posts nothing until the exact message is approved.
8. **Is a pull request already in play?** If review comments are waiting on the user's own PR, that is
   `dt-pr-defense`. If the user is reviewing someone else's, `dt-pr-review`. If the PR exists and only
   its description is wrong, `dt-pr-data`.
9. **Is the session about to end or be handed over?** `dt-handoff`, before anything else gets lost.
10. **Are there open design decisions nobody has made yet?** `dt-grilling`. It interviews in rounds
   until the design is agreed, looks facts up itself, and hands back a decision tree. Reach for it
   whenever starting would mean guessing at what someone wanted.
11. **Is the work understood but too big to do in one pass?** `dt-to-tasks`, to break it into vertical
   tasks with their blocking edges. It asks nothing about requirements, only about the breakdown.
12. **Is a ticket too thin to build from?** `dt-ticket-refiner`. Only a person can invoke it, and it
   writes to Jira, so it asks before every edit.
13. **Is the work understood and the ask is to build it?** `dt-implement`. It handles the tests, the
   loop, the review and the commit. Reach for `dt-tdd-prep` on its own only when the tests are all
   that is wanted.
14. **Does the user not yet know how the thing works?** `dt-investigation`. This is the honest answer
   whenever the next step is guesswork, and it is the most common right answer at the start.
15. **Is there a change on the branch to review before a PR exists?** `dt-code-review` for a normal
   change. `dt-overkill-code-review` when it is large, touches money or data, or would be expensive
   to get wrong, and say what that costs first: three full reviews of the same diff. Once a PR is
   open, `dt-pr-review` is the one to reach for, and it picks between these two by PR size itself.
16. **Is a component moving from styled-components to Tailwind?** `dt-tailwind-migration-tool`. It
    screens first and refuses on `applyFont` or breakpoints, which is most components today.
17. **Does a component need a Storybook story?** `dt-storybook-creator`. It screens first, and about
   half of what gets asked for should not have one.
18. **Is a staging test account needed?** `dt-test-account`. Staging only, and the backend picks the
   password rather than you.
19. **Is the deliverable words rather than code?** `dt-unslop`, on its own.
20. **Is a change written and cluttered with comments?** `dt-unslop-code`. `dt-implement` already
    runs it, so reach for it separately only when the code was written outside that flow.
21. **Does the user want a new dt skill?** `dt-skill-creator`. Only a person can invoke it, so say
    that if an agent is the one asking.
22. **Did a run just show a skill should have known something?** `dt-auto-improve-skill`. Most runs
   teach nothing, and saying so is the right answer.
23. **None of the above.** Say so. See below.

Two signals beat the list. If the user named a skill, they get that skill. If a phase inside a skill
already running says to call another, that instruction wins over anything here.

## Your answer

Four short parts, no preamble.

```
Run:    dt-tdd-prep
Why:    you know the arrows change colour, and nothing covers the arrow behaviour today
Call:   /dt-tdd-prep AnimatedOddsValue
Then:   implement it yourself, then /dt-pr-data once the PR is open
```

If two skills genuinely fit, name the one to run first and say what triggers the second. Do not lay
out a five step programme. The user asks again when they get there.

Then offer to run it. Run it yourself only if the user has already made it clear they want the work
done rather than the answer.

## When no skill fits

Say "none of these, just do the work" and mean it. A skill is overhead, and plenty of tasks are
faster done directly:

- A one line fix in code the user already understands
- A question you can answer by reading one file
- Anything with no repository involved
- Work already underway that a skill would restart

Recommending a skill for a two minute job is the failure mode of a router.

## Keep the map honest

The roster above is what existed when this was written. Check what is actually installed before
answering, since the set changes:

```bash
for f in ${CLAUDE_PLUGIN_ROOT}/skills/dt-*/SKILL.md; do
  printf '%-22s %s\n' "$(basename "$(dirname "$f")")" "$(sed -n 's/^description: //p' "$f" | cut -c1-90)"
done
```

If a skill appears there and not here, use it and tell the user this map needs updating. Never
recommend a skill that is not in that listing. A confident wrong name costs more than saying you do
not know.

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.
