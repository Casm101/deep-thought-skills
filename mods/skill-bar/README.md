# skill-bar

A row of buttons above the prompt, one for each of the six dt skills typed most often. A button puts
its command at the front of the prompt box, keeping anything already typed after it, so you add a
ticket or PR and press Enter yourself. Pressing another swaps the command and keeps the rest. Works
in the terminal and the desktop app's Code tab.

| Key | Button | Fills in |
| --- | --- | --- |
| 1 | PR Review | `/deep-thought:dt-pr-review` |
| 2 | Branch Update | `/deep-thought:dt-branch-update` |
| 3 | PR Defense | `/deep-thought:dt-pr-defense` |
| 4 | Work Summary | `/deep-thought:dt-work-summary` |
| 5 | Skill Creator | `/deep-thought:dt-skill-creator` |
| 6 | Auto Develop | `/deep-thought:dt-auto-develop` |

In the desktop app, click a button. In the terminal, click the row or press ctrl+x tab, then press the
number. A skill that is not installed has no button. `/skill-bar` hides the row and brings it back,
and the choice is kept across sessions.

The list is `SKILLS` at the top of `hooks/register.tsx`.

## Install

```
/plugin install skill-bar --marketplace Casm101/deep-thought-skills
```

## Develop

```
claude plugin validate mods/skill-bar
claude plugin test mods/skill-bar
```
