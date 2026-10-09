# Proving a mod works

`mod-check.sh check <mod>` runs the three gates. This file covers what they cannot do alone: the
test kit's gaps, looking at what the mod draws, and playing an interactive one.

## The three gates

1. `plugin validate` reads the manifest and the module the way the engine will. Read its `hooks:`,
   `calls:` and `gating hook` lines, not only the last one. They say what the engine thinks the mod
   does.
2. The typecheck runs on a scratch tsconfig under `$TMPDIR` that names this build's
   `claude-code.d.ts`. Before a mod has ever loaded, that file only exists once `plugin-authoring`
   has loaded in the session; `MOD_TYPES=<path>` overrides the search.
3. `plugin test` runs every `*.test.ts` against the real engine.

The script uses `$CLAUDE_CODE_EXECPATH`, the build that will load the mod, and falls back to the
`claude` on `PATH`, which may be older.

## The test kit's gaps

Nothing sits beneath the plugin in a test, so a hook that passes with `next(e)` fails with "no
implementation". Stand in for the engine:

```ts
import type { On } from 'claude-code'
import { expect, mock, test } from 'claude-code/testing'

const engine = (on: On): string[] => {
  const toasts: string[] = []
  mock.store(on)
  on('ui.render', { component: 'AbovePrompt' }, ($, e) => $.ui.resolve(e).Text({ children: 'empty band' }))
  on('ui.toast', ($, e) => {
    toasts.push(e.text)
    return { value: undefined }
  })
  return toasts
}
```

- The test's `$` has no `state` noun. Assert through the drawing, for example by remounting and
  finding the persisted value.
- `$.command.run` needs `origin: { kind: 'composer' }` and `presentation: { isFullscreen: false,
  columns: 80 }`.
- A band mounts with `props: { hasSurvey: false, isWorking, maxRows: 20, bodyColumns: 80, scroll: {
  offset: 0, bodyRows: 20 }, view: {} }`.
- `ui.advance(ms)` drives `surface.every`. `ui.key`, `ui.pointer` and `ui.resize` act on a
  `Client`, addressed with `in: '<key>'`.
- Write each test once and loop it over `['terminal', 'desktop'] as const`.

## Look at what it draws

Passing tests say nothing about whether the band reads well. For anything drawn, add a scratch test
that prints frames. `console.log` works under `plugin test`:

```ts
const rows = (node: unknown): string[] => {
  const el = node as { type?: string; children?: unknown[] }
  if (!el || typeof el !== 'object') return []
  const kids = el.children ?? []
  const flat = kids.every(k => typeof k === 'string' || (k as { type?: string })?.type === 'Text')
  const text = (k: unknown): string =>
    typeof k === 'string' ? k : ((k as { children?: unknown[] }).children ?? []).map(text).join('')
  return el.type === 'Box' && flat ? [kids.map(text).join('')] : kids.flatMap(rows)
}

test('frames', async ($, on) => {
  engine(on)
  const ui = await $.ui.mount({ plugin: '<name>', surface: 'terminal', component: 'AbovePrompt', props: BAND })
  await ui.resize({ columns: 60, rows: 7, in: '<client key>' })
  for (const ms of [0, 500, 2000]) {
    await ui.advance(ms)
    console.log(rows(await ui.drawn({ in: '<client key>' })).join('\n'))
  }
})
```

`ui.drawn()` with no argument is the hook's own tree, and `{ in }` reads a `Client`'s. Show the
person two or three frames in the session, in a code block, before Phase 5. Then delete the scratch
test.

## Play an interactive one

For a game or anything driven by keys, write a throwaway bot test. It reads the drawn rows each tick,
decides a key from what it sees, and presses it, for long enough to show the thing is winnable or
usable. If the bot cannot get as far as a person could, fix the tuning. Delete the
bot test before Phase 6, and never commit it.
