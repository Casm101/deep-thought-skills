# message-times

A dim time under each message you send and each block of Claude's reply, so you can see when you
asked and when it answered. Works in the terminal and the desktop app's Code tab.

```
> add timestamps
  14:02
● Done.
  14:03
```

A message from an earlier day shows its date too, as `8 Oct 14:02`. Times are taken when each message is
written to the transcript and kept for roughly the last 2,000 messages, so a resumed session still
has them.
Messages from before the mod was installed have no time, rather than a guessed one. Subagent
transcripts and tool-only rows are left alone.

`/message-times` hides the times and brings them back, and the choice is kept across sessions.

## Install

```
/plugin install message-times --marketplace Casm101/deep-thought-skills
```

## Develop

```
claude plugin validate mods/message-times
claude plugin test mods/message-times
```
