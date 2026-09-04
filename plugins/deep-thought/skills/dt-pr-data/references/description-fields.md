# Fields: what to write, and who writes it

Three kinds of field. Sort every heading in the template into one before writing anything.

| Kind | You | Example |
|---|---|---|
| Machine-fillable | write it from the diff, commits, and ticket | Summary, Testing, Additional Notes |
| Placeholder | substitute mechanically | `{{BRANCH_NAME}}`, `TS-XXXX`, branch-flavoured preview URLs |
| Human-only | never invent, never delete, report at the end | screenshots, videos, design links, wiki updates, QA sign-off |

## Machine-fillable fields

### Summary / Description / What and why

Two short paragraphs at most, often one.

Paragraph one: what changed, in behaviour terms. Paragraph two, only if it earns its place: the cause,
for a fix, or the reason, for a feature. The ticket gives you the reason; the diff gives you the
change.

```
Race pills in the meetings row now scroll by click and drag, in all three racing verticals.

The row borrowed the tag-list styles but not the component that owns the drag behaviour, so it
scrolled by wheel only.
```

Not this:

```
This PR aims to improve the user experience of the meetings section by refactoring the race pill
list component to leverage the existing drag-scroll functionality, thereby improving consistency
and maintainability across the racing verticals...
```

### Changes / What changed

Only when the summary cannot carry it, usually for a diff that touches several areas. Bullets, one
line each, starting with a verb, ordered by importance rather than by file path.

```
- Route all three racing verticals through a new shared MeetingRacePillList
- Compare pointer travel rather than scroll distance when suppressing the click after a drag
- Drop the mount-time window listeners that swallowed the first mouseup after any slider mounted
```

Group by behaviour, never file by file. A reviewer can read the file list themselves.

### Testing / How to test

Numbered steps someone else can follow without asking you anything. Start from where they must be,
then the action, then what they should see. Use the ticket's reproduction steps when there are any:
they are already written in the reporter's words.

```
1. Open a Greyhound racing page on a meeting with more than 12 races
2. Click and drag the race pill row sideways
3. The row scrolls, and releasing the drag does not open a racecard
4. Click a pill without dragging, the racecard opens as before
```

Then, if tests were touched, one line naming what they cover:

```
Covered by useDragScroll and MeetingRacePillList unit tests.
```

If nothing automated covers it, say that plainly. Do not imply coverage that is not there.

### Additional Notes

Only for something a reviewer would otherwise trip on: a deliberate omission, a follow-up ticket, a
migration ordering, a risk. If there is nothing, write nothing rather than filler. Leave the heading.

### Type of change

If the template has classification checkboxes and the diff settles the answer, tick the one box that
matches (bug fix, feature, chore) and say so in the report. Leave every other box as you found it.

## Placeholder substitution

- `{{BRANCH_NAME}}` and similar: the head branch name, exactly as the script printed it. This is what
  makes the environment preview tables and any CDN or flavour URLs work, so fill every occurrence.
- `TS-XXXX`, `PROJ-1234`: the real ticket key, in the link text and in the URL.
- Keep the surrounding markup exactly as the template wrote it, including HTML anchors and table
  pipes. Substitute inside it, do not rebuild it.
- A placeholder whose value you do not have stays as it is, and goes in the "needs you" report.

## Human-only fields

Never fabricate these, and never quietly delete their markup.

- **Screenshots, GIFs, videos, showcase.** leave the placeholder markup in place and report what
  footage is needed, specifically: which screen, which state, which viewport, before and after if the
  change is visual.
- **Design links (Figma, Zeplin).** fill only if a link appears in the ticket or the existing body.
  Otherwise leave the placeholder and report it, noting whether the ticket referenced a design at all.
- **Wiki or documentation updates** (for example a Mixpanel tracking page): you cannot know it was
  done. Check whether the diff changes tracking events; if it does, report that the wiki needs
  updating; if it does not, report that nothing is needed.
- **Manual QA, sign-off, checklists that assert someone tested something.** never tick these.
- **Anything a reviewer or the author already wrote in the body.** preserve it.

## Generic repos with no template

Map whatever headings exist onto the same kinds. Common names you will meet:

| Heading | Treat as |
|---|---|
| Description, Summary, What, Why, Motivation, Context | Summary |
| Changes, What changed, Implementation | Changes |
| Testing, How to test, Test plan, Verification, QA steps | Testing |
| Screenshots, Demo, Recording, Showcase, Visual proof | Human-only |
| Breaking changes, Migration, Rollout, Risk | Additional Notes, only if the diff shows one |
| Checklist, Definition of done | Leave alone, report what the diff supports |
| Related issues, Linked tickets, Closes | Ticket link and key |

With no template and no merged-PR precedent, use Summary, Changes, Testing, Notes, and stop there. A
short honest description beats a long invented one.
