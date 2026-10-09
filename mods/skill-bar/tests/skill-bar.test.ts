import type { On } from 'claude-code'
import { expect, mock, test } from 'claude-code/testing'

const SURFACES = ['terminal', 'desktop'] as const
const typed = { args: '', origin: { kind: 'composer' as const }, presentation: { isFullscreen: false, columns: 80 } }
const INSTALLED = [
  'deep-thought:dt-pr-review',
  'deep-thought:dt-branch-update',
  'deep-thought:dt-pr-defense',
  'deep-thought:dt-work-summary',
  'deep-thought:dt-skill-creator',
  'deep-thought:dt-auto-develop',
  'deep-thought:dt-unslop',
  'compact',
]

// Stands in for the engine beneath the plugin: its own empty band, a store, the
// session's slash commands, a prompt box holding `draft`, and a record of what ran.
const engine = (on: On, { installed = INSTALLED, draft = '' } = {}) => {
  const ran: string[] = []
  const filled: string[] = []
  mock.store(on)
  on('ui.render', { component: 'AbovePrompt' }, ($, e) => $.ui.resolve(e).Text({ children: 'empty band' }))
  on('command.list', () => ({
    value: installed.map(name => ({ name, description: '', source: 'plugin' as const })),
  }))
  on('command.run', ($, e) => {
    ran.push(e.command)

    return { text: '' }
  })
  on('prompt.read', () => ({ value: { text: draft, cursor: draft.length } }))
  on('prompt.fill', ($, e) => {
    filled.push(e.text)

    return { isFilled: true }
  })

  return { ran, filled }
}

const band = <S extends 'terminal' | 'desktop' | 'vscode' | 'mobile'>(surface: S, hasSurvey = false) => ({
  plugin: 'skill-bar',
  surface,
  component: 'AbovePrompt' as const,
  props: {
    hasSurvey,
    isWorking: false,
    maxRows: 20,
    bodyColumns: 100,
    scroll: { offset: 0, bodyRows: 20 },
    view: {},
  },
})

for (const surface of SURFACES) {
  test(`${surface}: the bar shows the six skills by their plain names, in order`, async ($, on) => {
    engine(on)
    const ui = await $.ui.mount(band(surface))

    const labels = []
    for (const key of INSTALLED.slice(0, 6)) labels.push((await ui.find({ type: 'Button', key }))?.props.label)
    expect(labels).toEqual(['PR Review', 'Branch Update', 'PR Defense', 'Work Summary', 'Skill Creator', 'Auto Develop'])
    expect(await ui.find({ type: 'Button', key: 'deep-thought:dt-unslop' })).toBeUndefined()
    await ui.unmount()
  })

  test(`${surface}: a press puts the command in the prompt box and runs nothing`, async ($, on) => {
    const { ran, filled } = engine(on)
    const ui = await $.ui.mount(band(surface))

    await ui.press({ key: 'deep-thought:dt-auto-develop' })
    expect(filled).toEqual(['/deep-thought:dt-auto-develop '])
    expect(ran).toEqual([])
    await ui.unmount()
  })

  test(`${surface}: a press keeps what was typed and replaces an earlier command`, async ($, on) => {
    const typedFirst = engine(on, { draft: 'TS-1234' })
    const ui = await $.ui.mount(band(surface))
    await ui.press({ key: 'deep-thought:dt-auto-develop' })
    expect(typedFirst.filled).toEqual(['/deep-thought:dt-auto-develop TS-1234'])
    await ui.unmount()
  })

  test(`${surface}: /skill-bar hides the bar and brings it back`, async ($, on) => {
    engine(on)

    await $.command.run({ command: 'skill-bar', ...typed })
    const hidden = await $.ui.mount(band(surface))
    expect(await hidden.find({ type: 'Button' })).toBeUndefined()
    expect(await hidden.find({ text: 'empty band' })).toBeDefined()
    await hidden.unmount()

    await $.command.run({ command: 'skill-bar', ...typed })
    const shown = await $.ui.mount(band(surface))
    expect(await shown.find({ type: 'Button', key: 'deep-thought:dt-pr-review' })).toBeDefined()
    await shown.unmount()
  })

  test(`${surface}: a survey takes the band`, async ($, on) => {
    engine(on)
    const ui = await $.ui.mount(band(surface, true))
    expect(await ui.find({ type: 'Button' })).toBeUndefined()
    await ui.unmount()
  })
}

test('a second press swaps the command and keeps the arguments', async ($, on) => {
  const { filled } = engine(on, { draft: '/deep-thought:dt-pr-review 4521' })
  const ui = await $.ui.mount(band('desktop'))
  await ui.press({ key: 'deep-thought:dt-pr-defense' })
  expect(filled).toEqual(['/deep-thought:dt-pr-defense 4521'])
  await ui.unmount()
})

test('buttons are drawn plain, with their number, on both surfaces', async ($, on) => {
  engine(on)
  for (const surface of SURFACES) {
    const ui = await $.ui.mount(band(surface))
    const button = await ui.find({ type: 'Button', key: 'deep-thought:dt-pr-review' })
    expect(button?.props.plain).toBe(true)
    expect(button?.props.hotkey).toBe('1')
    await ui.unmount()
  }
})

test('a skill that is not installed gets no button', async ($, on) => {
  engine(on, { installed: ['deep-thought:dt-pr-review', 'deep-thought:dt-auto-develop'] })
  const ui = await $.ui.mount(band('terminal'))

  expect((await ui.find({ type: 'Button', key: 'deep-thought:dt-pr-review' }))?.props.label).toBe('PR Review')
  expect(await ui.find({ type: 'Button', key: 'deep-thought:dt-branch-update' })).toBeUndefined()
  await ui.unmount()
})

test('VS Code and mobile draw the engine band, not the bar', async ($, on) => {
  engine(on)
  for (const surface of ['vscode', 'mobile'] as const) {
    const ui = await $.ui.mount(band(surface))
    expect(await ui.find({ type: 'Button' })).toBeUndefined()
    await ui.unmount()
  }
})
