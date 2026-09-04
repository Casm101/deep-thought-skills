# What a refined ticket looks like

Match the project first. What follows is the fallback when the project has no clear pattern, and the
set of rules that holds whatever the shape.

## The structure

```markdown
## What and why

Race-card x-cast bets (combination forecasts and tricasts) render wrongly in My Bets. A punter sees
the runners they picked rather than the finishing order, and every combination as a separate row.

## Current behaviour

`racingXCast.ts` groups by combination rather than by event, so a three-runner tricast shows six rows.
Runner names carry their finishing position, and the settled order is never read.

## Wanted behaviour

One row per event. Runner names without positions. Once the legs settle, the real finishing order in
place of the picked runners.

## Acceptance criteria

- A settled combination tricast shows the finishing order the race produced, per leg
- An unsettled one shows the picked runners, unchanged from today
- A leg with a non-runner shows the substitute rather than a blank
- One display group per event, not one per combination
- Existing single forecast behaviour is untouched

## Out of scope

The per-consumer storage reads in the seasonal hooks. Tracked separately.

## Open questions

Should a two-of-three non-runner tricast still show a finishing order, or fall back to picked runners?
Nothing in the code or the thread settles it.

## Original report

<the reporter's text, verbatim, unchanged>
```

Drop any heading that has nothing real in it. An empty `Open questions` is better absent.

## The rules

**The original survives.** Verbatim, at the bottom, under its own heading. Jira keeps an edit history
that nobody reads, so the ticket itself has to carry what the reporter wrote. This is also what makes
the edit safe to approve: nothing is lost, only added above.

**Every requirement traces to a source.** The ticket text, a comment, the code, or a document. When
you write a requirement, you should be able to say where it came from without thinking.

**An inference is a question, not a requirement.** If the ticket implies something and nothing
confirms it, it goes under `Open questions` phrased as a question. Never promote a guess into an
acceptance criterion, because the next person cannot tell which lines were specified and which were
invented.

**Acceptance criteria are checkable.** Each one holds or does not, with no judgement call.

```
good  A leg with a non-runner shows the substitute rather than a blank
good  One display group per event, not one per combination
bad   Non-runners are handled correctly
bad   The UI is improved
bad   Refactor racingXCast.ts to group by event      (implementation, not behaviour)
```

**Criteria describe behaviour, not implementation.** How to build it is the implementer's decision and
it goes stale the moment they start. Naming a file in a criterion is almost always a mistake.

**Current behaviour is stated, not implied.** A reader who has never opened the code needs to know
what is wrong before they can judge what right looks like. This is the section the investigation pays
for.

**Out of scope earns its place.** One line preventing one argument later. Say what a reasonable person
might assume is included and is not.

**Keep the ticket's own vocabulary.** If the reporter says "box", do not switch to "combination
group" because the code does. Add the code's term alongside it once, then use theirs.

## Length

A refined ticket is shorter than people expect. Five criteria that each mean something beat twelve
that overlap. If the description runs past a screen, most of it is either implementation detail or the
same point twice.

Two paragraphs per section at most. If a section needs more, it is probably two tickets.

## What does not belong

**A design document.** The repo has a template for those, and a ticket is not one. No architecture
section, no API tables, no performance analysis. Link the design doc if one exists.

**A task breakdown.** Slicing the work into tasks is a different job and a different skill.

**Estimates, priorities, or who should do it.** Not yours to set.

**Anything about how the refinement was produced.** No note that it was refined, no mention of this
skill, no summary of what changed. The edit history records that, and the ticket should read as though
it was always this clear.
