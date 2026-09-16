# What cannot make the trip, and what to do about each

An artifact is a page plus a host. The export carries the page. Everything the host was providing
stops at the door.

## Runtime capabilities

A page calling `window.claude.*` is asking the host for something. Outside it, that object does not
exist, and an unguarded call throws on load and takes the rest of the script with it. So a page that
merely stored a preference breaks completely, which is a worse outcome than losing the preference.

| Capability | What goes | What the reader sees |
|---|---|---|
| `db` | Everything anyone saved. Polls, checklists, trackers, edited documents | The empty first-run state |
| `user` | Who is viewing | No name, no per-person view, no permissions |
| `assets` | Files people uploaded through the page | Broken images and dead download buttons |
| `completion` | The page's own questions to Claude | Whatever the page does when an answer never arrives |

**The stub.** Put this before every other script, so a call fails quietly rather than killing the page:

```html
<script>
window.claude = new Proxy({}, { get: () => async () => {
  throw new Error('This is an exported copy. Live data is not available.');
}});
</script>
```

A rejected promise beats a missing object, because most pages already handle a failed call and none
handle `undefined`.

**The banner.** A stranger opening this has no idea anything is missing, so say it on the page itself,
at the top, in the page's own voice. Name what is gone, not the mechanism:

```html
<div style="padding:10px 14px;background:#FDF6E3;border-bottom:1px solid #E8DCC0;
            font:13px/1.5 system-ui,sans-serif;color:#5C4A1E">
  Exported copy. The saved entries and anything added since are not in this file.
</div>
```

Run `dt-unslop` over the wording before it goes in. It is prose a stranger reads.

**When the page is nothing but its capability.** A dashboard whose entire content loads from the
database exports as an empty shell. Refuse. Say which capability the page is built on, and that the
link is the only way to share it. A blank file that opens is more misleading than no file.

## Mermaid

Artifacts draw mermaid natively, so a page using it carries no library. Nothing outside draws it, and
the reader gets the raw diagram source as text.

Inline the library and start it, before the export:

```html
<script src="https://cdnjs.cloudflare.com/ajax/libs/mermaid/11.4.1/mermaid.min.js"></script>
<script>mermaid.initialize({ startOnLoad: true });</script>
```

The inliner folds that script in like any other. Check the diagram actually drew in Phase 4, because a
mermaid syntax error the host tolerated may not survive the version you just pinned.

## Supporting files

A multi-file artifact keeps its CSS, JS and data at published paths. `action: list_files` lists them,
`action: read_file` pulls each one. Put them beside the page in the scratchpad at the same relative
path the HTML uses, and the inliner treats them as ordinary local files.

Miss one and the export succeeds with a hole in it, which Phase 4 catches as a blank region or a
console error rather than as a failure. So list the files before transforming, not after.

## Things that survive fine

Worth knowing, so they do not get treated as risks: CSS including custom properties and
`prefers-color-scheme`, inline SVG, canvas, animation, `localStorage` (it starts empty and works from
there), every CDN library once inlined, and webfonts as data URIs.

## Things that were already broken

Artifacts run under a CSP that blocks downloads the page starts itself. An `<a download>` or a
script-driven save does nothing for a viewer of the published artifact. In an exported file opened
from disk those start working again, which is a change in behaviour worth mentioning rather than a
problem to fix.
