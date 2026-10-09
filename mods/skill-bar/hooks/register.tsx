import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { SkillButton } from '../types'

// The six dt commands typed most often, in the order the bar shows them.
const SKILLS = [
  'dt-pr-review',
  'dt-branch-update',
  'dt-pr-defense',
  'dt-work-summary',
  'dt-skill-creator',
  'dt-auto-develop',
]
const ACRONYMS: Record<string, string> = { pr: 'PR', tdd: 'TDD', ui: 'UI' }

const isHidden = atom({ plugin: 'skill-bar', key: 'isHidden' } as const, false)

const labelOf = (skill: string): string =>
  skill
    .replace(/^dt-/, '')
    .split('-')
    .map(word => ACRONYMS[word] ?? word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ')

// The plugin prefix is whatever this machine installed it under, so match on the real names.
const buttonsFrom = (names: readonly string[]): SkillButton[] =>
  SKILLS.flatMap(skill => {
    const command = names.find(name => name === skill || name.endsWith(`:${skill}`))

    return command === undefined ? [] : [{ label: labelOf(skill), command }]
  })

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const stored = await $.store.get('isHidden')
    await update($, isHidden, () => stored === true)
    await $.command.register({
      name: 'skill-bar',
      description: 'Hide or show the row of dt skill buttons above the prompt',
      immediate: true,
    })

    return next(e)
  })

  on('command.run', { command: 'skill-bar' }, async $ => {
    const hidden = !(await read($, isHidden))
    await update($, isHidden, () => hidden)
    await $.store.set('isHidden', hidden)

    return { text: hidden ? 'Skill bar hidden. /skill-bar brings it back.' : 'Skill bar shown.' }
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.surface !== 'terminal' && e.surface !== 'desktop') return next(e)
    if (e.props.hasSurvey || (await read($, isHidden))) return next(e)

    const list = buttonsFrom((await $.command.list()).map(command => command.name))
    if (list.length === 0) return next(e)

    const { Box, Button } = $.ui.resolve(e)
    // Puts the command in front of whatever is typed, replacing one a previous press put there,
    // so the person adds a ticket or PR and sends it themselves.
    const press = async (button: SkillButton) => {
      const { text } = await $.prompt.read()
      const rest = text.replace(/^\/\S+\s*/, '')
      await $.prompt.fill({ text: `/${button.command} ${rest}` })
    }

    return (
      <Box key="skill-bar" flexDirection="row" flexWrap="wrap" columnGap={2}>
        {list.map((button, index) => (
          <Button
            key={button.command}
            label={button.label}
            hotkey={String(index + 1)}
            plain
            onPress={() => void press(button)}
          />
        ))}
      </Box>
    )
  })
}
