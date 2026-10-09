import type { On } from 'claude-code'
import { expect, mock, test } from 'claude-code/testing'

const SURFACES = ['terminal', 'desktop'] as const
const typed = { args: '', origin: { kind: 'composer' as const }, presentation: { isFullscreen: false, columns: 80 } }

const todayAt = (hours: number, minutes: number) => {
  const at = new Date()
  at.setHours(hours, minutes, 0, 0)

  return at.getTime()
}

// Stands in for the engine beneath the plugin: a store, a clock, and its own
// drawing of a prompt and a reply.
const engine = (on: On, now: number) => {
  mock.store(on)
  const clock = mock.clock(on, { now })
  on('ui.render', { component: 'UserMessage' }, ($, e) => $.ui.resolve(e).Text({ children: `you: ${e.props.text}` }))
  on('ui.render', { component: 'AssistantMessage' }, ($, e) => $.ui.resolve(e).Text({ children: `claude: ${e.props.text}` }))

  return clock
}

const prompt = (uuid: string, text: string, agentId?: string) => ({
  message: { type: 'user' as const, role: 'user' as const, content: [{ type: 'text', text }] },
  door: 'prompt' as const,
  origin: { kind: 'composer' as const },
  uuid,
  ...(agentId === undefined ? {} : { agentId }),
})

const reply = (uuid: string, content: { type: string; text?: string }[]) => ({
  message: { type: 'assistant' as const, role: 'assistant' as const, content },
  door: 'response' as const,
  origin: { kind: 'model' as const, model: 'claude-opus-5-5' },
  uuid,
})

const userRow = <S extends 'terminal' | 'desktop' | 'vscode' | 'mobile'>(surface: S, requestId: string, text: string) => ({
  plugin: 'message-times',
  surface,
  component: 'UserMessage' as const,
  requestId,
  props: { text, origin: { kind: 'composer' as const }, isExpanded: true },
})

const replyRow = <S extends 'terminal' | 'desktop'>(surface: S, requestId: string, text: string) => ({
  plugin: 'message-times',
  surface,
  component: 'AssistantMessage' as const,
  requestId,
  props: { text, isFirstOfReply: true },
})

for (const surface of SURFACES) {
  test(`${surface}: a sent prompt shows the time under it`, async ($, on) => {
    engine(on, todayAt(9, 5))
    await $.session.append(prompt('u1', 'hi'))

    const ui = await $.ui.mount(userRow(surface, 'u1', 'hi'))
    expect(await ui.find({ text: 'you: hi' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '09:05' })).toBeDefined()
    await ui.unmount()
  })

  test(`${surface}: a reply block with text shows when it was written`, async ($, on) => {
    engine(on, todayAt(14, 2))
    await $.session.append(reply('a1', [{ type: 'text', text: 'done' }]))

    const ui = await $.ui.mount(replyRow(surface, 'msg_a-t0', 'done'))
    expect(await ui.find({ text: 'claude: done' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '14:02' })).toBeDefined()
    await ui.unmount()
  })

  test(`${surface}: a row from an earlier day carries its date`, async ($, on) => {
    engine(on, new Date(2026, 9, 8, 14, 2).getTime())
    await $.session.append(prompt('u2', 'yesterday'))

    const ui = await $.ui.mount(userRow(surface, 'u2', 'yesterday'))
    expect(await ui.find({ type: 'Text', text: '8 Oct 14:02' })).toBeDefined()
    await ui.unmount()
  })

  test(`${surface}: a row the mod never saw gets no time`, async ($, on) => {
    engine(on, todayAt(9, 5))

    const ui = await $.ui.mount(userRow(surface, 'old', 'from before the mod'))
    expect(await ui.find({ text: 'you: from before the mod' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^\d\d:\d\d$/ })).toBeUndefined()
    await ui.unmount()
  })

  test(`${surface}: /message-times hides the times and brings them back`, async ($, on) => {
    engine(on, todayAt(9, 5))
    await $.session.append(prompt('u3', 'hi'))

    await $.command.run({ command: 'message-times', ...typed })
    const hidden = await $.ui.mount(userRow(surface, 'u3', 'hi'))
    expect(await hidden.find({ type: 'Text', text: '09:05' })).toBeUndefined()
    await hidden.unmount()

    await $.command.run({ command: 'message-times', ...typed })
    const shown = await $.ui.mount(userRow(surface, 'u3', 'hi'))
    expect(await shown.find({ type: 'Text', text: '09:05' })).toBeDefined()
    await shown.unmount()
  })
}

test('tool-only reply rows and subagent rows are not stamped', async ($, on) => {
  engine(on, todayAt(9, 5))
  await $.session.append(reply('t1', [{ type: 'tool_use' }]))
  await $.session.append(prompt('s1', 'for the subagent', 'agent-1'))

  for (const [requestId, text] of [['t1', ''], ['s1', 'for the subagent']] as const) {
    const ui = await $.ui.mount(userRow('terminal', requestId, text))
    expect(await ui.find({ type: 'Text', text: '09:05' })).toBeUndefined()
    await ui.unmount()
  }
})

test('VS Code and mobile draw the engine row alone', async ($, on) => {
  engine(on, todayAt(9, 5))
  await $.session.append(prompt('u4', 'hi'))

  for (const surface of ['vscode', 'mobile'] as const) {
    const ui = await $.ui.mount(userRow(surface, 'u4', 'hi'))
    expect(await ui.find({ type: 'Text', text: '09:05' })).toBeUndefined()
    await ui.unmount()
  }
})

test('a reply keeps its own time when a later reply has the same text', async ($, on) => {
  const clock = engine(on, todayAt(9, 5))
  await $.session.append(reply('r1', [{ type: 'text', text: 'Done.' }]))
  const first = await $.ui.mount(replyRow('desktop', 'msg_first-t0', 'Done.'))
  expect(await first.find({ type: 'Text', text: '09:05' })).toBeDefined()
  await clock.advance(0)
  await first.unmount()

  await clock.set(todayAt(10, 30))
  await $.session.append(reply('r2', [{ type: 'text', text: 'Done.' }]))
  const second = await $.ui.mount(replyRow('desktop', 'msg_second-t0', 'Done.'))
  expect(await second.find({ type: 'Text', text: '10:30' })).toBeDefined()
  await second.unmount()

  const again = await $.ui.mount(replyRow('desktop', 'msg_first-t0', 'Done.'))
  expect(await again.find({ type: 'Text', text: '09:05' })).toBeDefined()
  await again.unmount()
})

test('a reply drawn with whitespace the row did not have still finds its time', async ($, on) => {
  engine(on, todayAt(11, 15))
  await $.session.append(reply('r3', [{ type: 'text', text: 'Line one.\n\nLine two.' }]))
  const ui = await $.ui.mount(replyRow('terminal', 'msg_ws-t0', '  Line one.\n\nLine two.\n'))
  expect(await ui.find({ type: 'Text', text: '11:15' })).toBeDefined()
  await ui.unmount()
})
