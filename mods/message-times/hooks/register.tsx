import { atom, memberOf, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { MessageTimes } from '../types'

// Keys kept across sessions, oldest dropped first. A reply takes two: its text and the id it is drawn under.
const KEEP = 4000
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

const times = atom({ plugin: 'message-times', key: 'times' } as const, 0)
const isHidden = atom({ plugin: 'message-times', key: 'isHidden' } as const, false)

// The store's copy, read once per load. Earlier sessions' rows are only found here.
let saved: MessageTimes | undefined

const loadSaved = async ($: EngineInterface): Promise<MessageTimes> => {
  if (saved === undefined) {
    const stored = await $.store.get('times')
    saved ??= typeof stored === 'object' && stored !== null ? { ...(stored as MessageTimes) } : {}
  }

  return saved
}

const remember = async ($: EngineInterface, key: string, at: number) => {
  await update($, memberOf(times, { requestId: key }), () => at)
  const map = await loadSaved($)
  map[key] = at
  const keys = Object.keys(map)
  for (const old of keys.slice(0, Math.max(0, keys.length - KEEP))) delete map[old]
  await $.store.set('times', { ...map })
}

// A reply is drawn under `<API message id>-t<n>`, which its transcript row does not carry,
// so a reply's time is found by its text. FNV-1a over the text with whitespace collapsed.
const textKey = (text: string): string => {
  let hash = 0x811c9dc5
  for (const char of text.trim().replace(/\s+/g, ' ')) {
    hash ^= char.codePointAt(0) ?? 0
    hash = Math.imul(hash, 0x01000193)
  }

  return `text:${(hash >>> 0).toString(16)}`
}

const lookup = async ($: EngineInterface, key: string): Promise<number> =>
  (await read($, memberOf(times, { requestId: key }))) || (await loadSaved($))[key] || 0

const pad = (n: number) => String(n).padStart(2, '0')

const stampOf = (at: number, now: number): string => {
  const when = new Date(at)
  const time = `${pad(when.getHours())}:${pad(when.getMinutes())}`

  return when.toDateString() === new Date(now).toDateString()
    ? time
    : `${when.getDate()} ${MONTHS[when.getMonth()]} ${time}`
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const stored = await $.store.get('isHidden')
    await update($, isHidden, () => stored === true)
    await $.command.register({
      name: 'message-times',
      description: 'Hide or show the time under each message',
      immediate: true,
    })

    return next(e)
  })

  on('command.run', { command: 'message-times' }, async $ => {
    const hidden = !(await read($, isHidden))
    await update($, isHidden, () => hidden)
    await $.store.set('isHidden', hidden)

    return { text: hidden ? 'Message times hidden. /message-times brings them back.' : 'Message times shown.' }
  })

  // A prompt the person sent is drawn under its row's uuid; a reply block is found by its text.
  on('session.append', async ($, e, next) => {
    const result = await next(e)
    if (e.agentId !== undefined || e.message.isMeta) return result

    if (e.door === 'prompt') {
      await remember($, e.uuid, await $.clock.now())
    } else if (e.door === 'response') {
      const texts = e.message.content.flatMap(block => (block.type === 'text' && typeof block.text === 'string' ? [block.text] : []))
      if (texts.length > 0) {
        const at = await $.clock.now()
        for (const text of texts) await remember($, textKey(text), at)
      }
    }

    return result
  }).catch(($, e, next) => next(e))

  on('ui.render', { component: 'UserMessage' }, async ($, e, next) => {
    if (e.surface !== 'terminal' && e.surface !== 'desktop') return next(e)
    if (await read($, isHidden)) return next(e)
    const at = await lookup($, e.requestId)
    if (!at) return next(e)

    const own = await next(e)
    const { Box, Text } = $.ui.resolve(e)

    // The desktop draws the person's message as a bubble on the right, so the time goes under it there.
    return (
      <Box flexDirection="column">
        {own}
        {e.surface === 'desktop' ? (
          <Box justifyContent="flex-end">
            <Text color="inactive" dimColor>{stampOf(at, Date.now())}</Text>
          </Box>
        ) : (
          <Box paddingLeft={2}>
            <Text color="inactive" dimColor>{stampOf(at, Date.now())}</Text>
          </Box>
        )}
      </Box>
    )
  })

  on('ui.render', { component: 'AssistantMessage' }, async ($, e, next) => {
    if (e.surface !== 'terminal' && e.surface !== 'desktop') return next(e)
    if (await read($, isHidden)) return next(e)

    let at = await lookup($, e.requestId)
    if (!at) {
      at = await lookup($, textKey(e.props.text))
      // Pin it to this block, so a later reply with the same text cannot move it. A drawing never writes, so later.
      if (at) $.clock.after(0, () => void remember($, e.requestId, at))
    }
    if (!at) return next(e)

    const own = await next(e)
    const { Box, Text } = $.ui.resolve(e)

    return (
      <Box flexDirection="column">
        {own}
        <Box paddingLeft={e.surface === 'terminal' ? 2 : 0}>
          <Text color="inactive" dimColor>{stampOf(at, Date.now())}</Text>
        </Box>
      </Box>
    )
  })
}
