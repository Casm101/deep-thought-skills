# Building a mod in deep-thought-skills

What `plugin-authoring` does not say, because it is about this repository and this machine. For the
API itself, grep the d.ts that skill names: `grep -n "AbovePrompt: {" <types>`, `grep -n
"'tool.call'" <types>`, then read the declaration it lands on.

## The layout

```
mods/<name>/
  .claude-plugin/plugin.json
  hooks/hooks.json          { "modules": ["./register.tsx"] }
  hooks/register.tsx        the hooks module
  hooks/<thing>.tsx         a Client surface module, only for something animated or interactive
  types/index.d.ts          the state contract, only when the mod keeps $.state values
  tests/<name>.test.ts      at least one, run by `claude plugin test`
  README.md
```

The engine lays `.claude-plugin/types/` beside a mod each time it loads it. It is generated, so the
repo's `.gitignore` carries `mods/*/.claude-plugin/types/`. Add that line with the first mod if it
is missing.

`plugin.json`:

```json
{
  "name": "<name>",
  "version": "0.1.0",
  "description": "<one line>",
  "author": { "name": "Christian Smith Mantas" },
  "types": "./types/index.d.ts"
}
```

Drop `types` when there is no contract. The marketplace entry, appended to `plugins` in
`.claude-plugin/marketplace.json`:

```json
{
  "name": "<name>",
  "description": "<what it does and how to drive it, one or two sentences>",
  "author": { "name": "Christian Smith Mantas" },
  "source": "./mods/<name>"
}
```

## The hooks module

Start every `ui.render` hook with the surface guard, so the mod never draws where nothing shows it:

```tsx
on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
  if (e.surface !== 'terminal' && e.surface !== 'desktop') return next(e)
  const { Box, Text } = $.ui.resolve(e)
  // ...
})
```

- Keep anything a drawing reads in `$.state` (`atom`, `read`, `update` from `'claude-code'`), and
  anything that should outlive the session in `$.store` as well. Module variables die on every hot
  reload.
- Size a band or pane to `e.props.bodyColumns`, not `e.viewport.columns`.
- A guard on `tool.call`, `prompt.submit` or `command.run` carries a `.catch` that refuses where
  `next` was not called. `claude plugin validate` lists every gating hook with or without one.
- A slash command is `$.command.register` in `session.start` plus a `command.run` hook returning
  `{ text }`.

## Where it shows

| Site or element | Terminal | Desktop Code tab |
|---|---|---|
| `Pane`, `AbovePrompt`, message and tool rows, `CommandOutput`, `AskUserQuestion`, `Spinner`, `SessionMode`, `PromptHint` | yes | yes |
| `ToolProgress`, `TurnDuration`, `InfoNotice` | yes | no |
| `Raster`, `Image` | yes | no |
| `Svg` | no | yes |
| `Client`, `Input`, `Select`, `Box`, `Text`, `Button`, `Link`, `Code`, `Markdown` | yes | yes |

The VS Code chat panel, `claude -p`, the Agent SDK and cloud sessions run the hooks but draw
nothing. Remote Control draws in the host's terminal. The settings `statusLine` is a shell script
and has nothing to do with mods; a mod's status line is `$.ui.status(text)`.

A pane opened unasked (from `session.start` or a timer) seats only from 144 terminal columns. Open
one from a command or a button press, or check `e.viewport.isFullscreen` first.

## Client modules, for anything animated or interactive

`<Client key="x" module="./x.tsx" props={...} width={...} height={...} />` runs that file on the
drawing thread, terminal and desktop only. `module` must be a string literal.

- `surface.every(ms, fn)` is the frame clock. Start it once, while `surface.state` is still
  `undefined`.
- Keep all game state in one plain mutable object stored with `setState({ game })`. Mutate it in
  the timer and call `setState` to redraw. Never call `setState` from the render path after the
  first call. Three in a row unmount the instance as a render loop.
- `onKey` gets keys only after a click gives the region focus. Esc hands focus back to the prompt.
- `onPointer` handles clicks. `surface.post(data)` reaches the hooks module's `ui.message` hook.
- `surface.columns` is 0 before the first layout, so pass the width in props as a fallback.
- A `Text` with a `key` prop is refused. Key only `Box`es.

Half-block pixel art (`▀ ▄ █`) gives two pixels per cell. Snap anything that moves vertically to
whole rows (`2 * Math.round(y / 2)`), or a sprite shifted by an odd pixel smears across cells, and
bottom-align sprites of even pixel height.

## Flagged behaviour

Mods are not sandboxed. These need the person to have asked for them by name, and a line in the
hand back when they did:

- answering `tool.check` with an allow, or answering a `tool.call` that would have asked for
  permission
- anything relying on `allowModsToOverrideDenyRules`
- `$.http`, or a `$.process` that sends data, carrying prompts, transcript rows, file contents or
  tool output off the machine

Refuse outright anything that records, ranks or scores what a person does.

## The README

Short, and in this order: what it does in two sentences, where it shows, its keys or commands as a
table, then the two blocks below. Run `dt-unslop` over it.

````markdown
## Install

```
/plugin install <name> --marketplace Casm101/deep-thought-skills
```

## Develop

```
claude plugin validate mods/<name>
claude plugin test mods/<name>
```
````
