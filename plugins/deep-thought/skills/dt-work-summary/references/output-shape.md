# The two forms

Both, every time, in this order, with nothing around them.

## Form one, the summary

One paragraph. Three to six sentences. No heading, no bullets inside it, no bold.

It reads like an answer to "what did you get done?", spoken to a colleague who knows the product but
not the branch. Lead with what shipped, then what is open, then what was done for other people. Where
the window is not the one that was asked for, the first sentence says so and then moves on.

## Form two, the bullets

A flat list. One work item per bullet. A hyphen, then the bullet, then nothing.

**Fifteen words is a ceiling, not a target.** Count them. A sixteen word bullet gets rewritten, not
shipped, and the usual fix is cutting the clause explaining why.

Every bullet carries an outcome and a state. No sub-bullets, no headings grouping them by repository,
no bold labels at the front. Flat, because the point of this form is that it pastes into a standup
box without editing.

## Worked example

A three day gather found five commits, six pull requests of your own, and five reviews. Sixteen
records. They collapse to seven work items.

The summary drops the subject, the way people actually speak in a standup. "Packaged the dt skills",
not "the dt skills were packaged by me".

```
Two each-way fixes went out in My Bets. Virtual racing bets now carry an Each
Way label, and that one merged; a placed each-way selection reads as won, still
open for review. The x-cast header no longer draws a connector it cannot reach,
and cashout tracking records which widget fired the event. Outside sportsbook-ui,
the dt skills are now a Claude Code plugin, the tailwind migration skill merged
in sports-kit, and the test account skill is up for review. Five pull requests
reviewed across both repositories.

- Virtual racing each-way bets now show an Each Way label, merged
- A placed each-way selection now reads as won in My Bets, open
- Cashout tracking events name the widget that fired them, open for review
- Stopped the x-cast header drawing a connector it cannot reach
- Packaged the dt skills as a Claude Code plugin
- Tailwind migration skill merged, test account skill open for review
- Reviewed five pull requests across sportsbook-ui and sports-kit
```

Longest bullet there is twelve words. Every item in the paragraph has a bullet, and every bullet has a
sentence behind it. A summary carrying work the bullets drop is the common failure, and it is why the
two forms get written together rather than one derived from the other.

## What a bullet is not

**Not a commit subject.** "TS-42160 Add Widget Name to cashout tracking events" is the record. The
bullet says what is now true.

**Not a truncated sentence from the summary.** The bullets are the same information compressed, and
they have to stand alone for a reader who never sees the paragraph.

**Not a ticket key on its own.** "TS-44608 done" tells a standup nothing. The key is optional in a
bullet and the outcome is not.

**Not padded.** Three real work items beat five where two were invented from a branch name.

## When there was nothing

One line, no bullets, no apology, no suggestion.

```
Nothing recorded in the last day. The most recent work was 27 August.
```
