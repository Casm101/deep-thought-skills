---
name: dt-artifact-export
description: 'Turn a Claude artifact into one self-contained HTML file that needs nothing else, so it can be downloaded, emailed and opened by anyone with no network. Reads the published page, folds in every stylesheet, script, webfont and image it references, writes the result to the Downloads folder, and proves it by loading it and checking that nothing leaves the machine. Takes an artifact URL or title, or finds it from the list. Works only on artifacts the user owns, and says plainly which parts of a page cannot survive the trip. Use when asked for "dt artifact export" or "deep thought artifact export", or to export, download or save an artifact, make it standalone, self-contained or a single file, or share one with somebody who cannot open the link.'
argument-hint: "An artifact URL or title. With nothing, it lists yours and asks which."
---

# dt-artifact-export

One file, no network, opens anywhere. Anything short of that is not an export.

## What decides success

Not whether the transform ran. Whether a stranger who opens the file on a plane sees the same page you
see. Phase 4 is the only phase that answers that, and it is the one worth protecting when time is
short.

## Phase 1. Find the artifact and read it

An artifact URL in the arguments is the artifact. A title is a lookup:

```
Artifact  action: list  scope: mine
```

With neither, list them and ask which one. Never guess between two similar titles.

Then read it:

```
Artifact  action: read  url: <the url>
```

This gives back the whole assembled page, opening `<!doctype html>` with the head the publisher wraps
around every artifact. That is the file to work from, not a fragment needing a wrapper built around it.

**Stop here if the artifact is not the user's own.** One shared with them comes back as a summary
rather than HTML, and a summary cannot be exported. Say that the export needs an artifact they own,
and that the owner can run it themselves.

Write the HTML to the scratchpad directory, never into the repository.

## Phase 2. Survey what cannot make the trip

Read the saved HTML before transforming anything. Three things do not survive, and finding them after
the export wastes the run.

**Runtime capabilities.** Grep for `window.claude`. A page calling it for its database, the viewer's
identity, the asset store or to ask Claude a question loses all of that outside the host, because the
host is what provides it. `references/what-breaks.md` covers what each one does when it goes, and
carries the stub and the banner to add.

**Native mermaid.** A `<pre class="mermaid">` block or a mermaid fence is drawn by the artifact host,
not by a browser. Nothing renders it in an exported file, so inline the library. The reference has the
exact tag.

**Supporting files.** `action: list_files` on a multi-file artifact names them. Pull each one with
`action: read_file` into the same scratchpad directory beside the page, so the inliner resolves them
as ordinary relative paths.

## Phase 3. Fold everything in

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-artifact-export/scripts/inline-artifact.sh <input.html> ~/Downloads/<slug>.html
```

The slug comes from the artifact title, lower case and hyphenated. The script refuses to overwrite and
suffixes the date instead, because the file already at that name may have been sent to somebody.

It fetches every stylesheet, script, font and image and rewrites them as inline blocks and data URIs,
then reports what it inlined, what failed and what is still reaching outside. **It exits 2 when
anything is left**, so treat a non-zero exit as a failed export and not a warning.

Pass `--all-subsets` when the page carries Cyrillic, Greek, Vietnamese or CJK text. The default keeps
only the latin ranges, which is most of the size saving on a webfont and wrong for those pages.

`references/inlining.md` covers what the script does, the traps behind each decision, and what to do
when it reports a failure.

## Phase 4. Prove it, by loading it

A file that greps clean can still render blank. Serve the directory and open it:

```bash
cd <the Downloads directory> && python3 -m http.server 8731 --bind 127.0.0.1
```

Open `http://127.0.0.1:8731/<slug>.html` in the Browser pane, then ask the page itself:

```js
({ bodyLen: document.body.innerText.trim().length,
   offHost: performance.getEntriesByType('resource')
              .filter(r => !r.name.startsWith('http://127.0.0.1')).map(r => r.name),
   fonts: document.fonts.size })
```

`offHost` must be empty. That is the single file claim, measured at runtime rather than guessed from
the source, and it catches what a grep cannot: a script that builds a URL and fetches it.

Take a screenshot and look at it. Then stop the server and close the tab.

**The Browser pane cannot open `file://`.** Serving over localhost is the way in, and reaching for a
file URL instead wastes a turn on an error that reads like a permissions problem.

A body with no text means the page needed something the export could not carry. Delete the file and
say so. Shipping a blank page as a success is the worst outcome this skill has.

## Phase 5. Hand back the path

Name the file, its size, and anything that changed about the page: a capability that is now inert, a
font that could not be fetched, an interaction that no longer works. Say it plainly, because the
person is about to send this to somebody.

Run `dt-unslop` over any banner text before it goes into the page, since a stranger reads it with no
context. Invoke it with the Skill tool as `dt-unslop`, or read
`${CLAUDE_PLUGIN_ROOT}/skills/dt-unslop/SKILL.md` and apply its rules if the tool is unavailable.

## Never

- Never call an export finished while the script exits non-zero or `offHost` is not empty.
- Never hand over a file whose body renders empty. Delete it and report the failure.
- Never overwrite a file in the Downloads folder. The one already there may have been sent.
- Never write anywhere but the Downloads folder and the scratchpad. Not the repository, ever.
- Never snapshot an artifact's database into an exported file unless asked. It holds what other
  viewers wrote, and exporting it sends their data to whoever gets the file.
- Never export an artifact the user does not own.
- Never claim an interaction still works without loading the page and checking.
- Never strip content to make the export succeed. A smaller file that lost a section is not the page.
- Never fetch from a host outside the artifact allowlist. A page reaching elsewhere was already
  broken, and following that reference is how an export pulls in something nobody inspected.

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.
