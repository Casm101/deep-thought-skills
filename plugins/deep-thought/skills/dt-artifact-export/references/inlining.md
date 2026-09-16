# The inliner, and why each decision is the way it is

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-artifact-export/scripts/inline-artifact.sh <in.html> <out.html> [--all-subsets]
```

A bash entry point that checks the arguments and protects the output name, then `inline.py` beside it
doing the work. Python rather than node on purpose: node here comes from nvm, and this family has
already been bitten by a shell hook that fires a version manager. `/usr/bin/python3` is always there.

## What it rewrites

Stylesheets and scripts become inline blocks. Images, video posters, and every `url()` inside a
stylesheet become data URIs. Relative paths resolve against the file that names them, so a `url()`
inside a fetched stylesheet resolves against the stylesheet rather than the page, which is the
difference between a working background image and a 404.

## The traps, each of which cost a real run

**Google Fonts serves by User-Agent.** Ask as curl and it returns TTF. Ask as a browser and it returns
WOFF2. One face of Archivo is 110,708 bytes as TTF and 5,628 as WOFF2, twenty times the size, and
nothing in the response says which one you got. The script sends a current Chrome string.

**A webfont ships one face per script.** The browser request also splits families by unicode range,
with a `/* latin */` comment before each `@font-face`. Keeping only the latin ranges is most of the
saving on a family carrying Cyrillic and Vietnamese cuts. Pass `--all-subsets` for a page that needs
them, and read the page first rather than assuming, because a single quoted sentence in Greek is easy
to miss and looks like mojibake when the range is gone.

**A variable font serves one file for several weights.** The same URL appears in several `@font-face`
rules, so it gets fetched once and cached. The bytes still land in the output once per rule, which is
correct CSS and not worth restructuring the stylesheet to avoid.

**`</script>` inside a bundle ends the block early.** Any library containing that string in a literal
turns the rest of the page into text. The script escapes it to `<\/script`. This is the classic way an
inlined bundle silently destroys a page, and it looks like a rendering bug rather than a quoting one.

**A link to a web page is not a dependency.** `<a href="https://example.com">` is content and stays.
Only `src`, `url()` and `@import` are things the reader needs a network for. The leftover check knows
the difference, which is why it can be strict.

## Reading the report

`INLINED` is what got folded in, with sizes. `FAILED` is what was reached for and did not arrive, with
the reason. `STILL REACHING OUTSIDE` is the verdict, and the script exits 2 whenever it is not empty.

A failure is not a warning. The page will render with a piece missing, usually silently.

**A 404 on a CDN script** means the artifact pinned a version that no longer exists. Find the nearest
version that does, edit the source HTML in the scratchpad, and rerun. Do not drop the script.

**A 400 from Google Fonts** means a family name the service does not have, usually a typo in the
artifact. The page already falls back, so it is safe to leave, but say so in the handover.

**A timeout** is usually the 25 second limit on a large bundle. Rerun before concluding anything.

## Size

There is no cap and no compression. A page pulling the Tailwind play CDN carries roughly 400KB of
compiler, and one pulling React and a chart library runs past a megabyte. That is the honest cost of a
file that opens with no network, and it is worth mentioning at handover rather than optimising away,
since every reduction is a piece of the page that stops working.

The one saving worth taking is the font subsets, and the script takes it by default.
