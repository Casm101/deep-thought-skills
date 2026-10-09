/** When each transcript row was written, in ms since the epoch, keyed by the row's uuid. */
export type MessageTimes = Record<string, number>

declare module 'claude-code' {
  interface PluginState {
    'message-times': {
      times: StateFamily<number>
      isHidden: boolean
    }
  }
}
