/** One button on the bar: what it says and the slash command it runs. */
export type SkillButton = { label: string; command: string }

declare module 'claude-code' {
  interface PluginState {
    'skill-bar': { isHidden: boolean }
  }
}
