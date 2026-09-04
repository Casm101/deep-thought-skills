# Tripwires and caps

An unattended run needs to know when to give up, because the alternative is a confident change nobody
wanted and a reviewer who has to unpick it.

Stopping is a good outcome. Report where you got to, run `dt-handoff`, and leave the branch as it is.
Never delete work on the way out, and never commit a red suite to tidy up.

## Stop before you start

- No checkable definition of done can be written from the ticket and the code.
- The preflight says NO-GO.
- The ticket asks for a decision rather than an implementation, for example "investigate whether we
  should move to X".
- The ticket is a spike, a research task, or says design needed.

## Stop on what the change would touch

Stop the moment the work would need a change in any of these, whatever the ticket says:

- Money movement. Payments, deposits, withdrawals, wallets, balances, bet placement or settlement
  amounts.
- Identity and access. Authentication, authorisation, sessions, permissions.
- Anything under AML, KYC, responsible gaming or fraud. Treat these as read only, always.
- Stored data shape. Migrations, persisted schemas, anything that rewrites what users already have
  saved.
- Secrets and credentials, in any form, including test fixtures that hold real ones.
- Generated code, unless the run also changes the source it is generated from and regenerates it
  properly.
- CI, deployment or release configuration.

Reading these is fine. Changing them unattended is not.

## Stop on a question you cannot honestly answer

Phase 4 answers its own questions. These are the ones it may not:

- **Low confidence and expensive to reverse.** A public interface, a stored shape, a URL, an event
  name, anything other teams consume.
- **User-visible copy that appears in many places**, or anything needing translation.
- **A trade-off with no basis in the repo.** If nothing in the code, the docs or the ticket points one
  way, you are inventing product direction.
- **Two readings of the ticket that lead to different builds.** Do not pick one and hope.

Report the question, your options, and which you would have chosen. That is a useful five minute
conversation, and it is what this skill is for when it stops.

## Caps, and what to do at each

| Cap | Limit | At the limit |
|---|---|---|
| Fix attempts on one failing test | 3 | Stop. Report the test, the failure, and each attempt. |
| Slices in one task with no progress | 3 | Stop. The design is fighting you, and the slicing is probably wrong. |
| Tasks in one run | 5 | Finish the current one, ship what is green, report the rest as not started. |
| Review rounds after fixes | 2 | Stop. Report the outstanding findings rather than a third pass. |
| Files touched outside the scope boundary | 0 | Stop at the first one. |

Progress means a failing test now passes, or a new acceptance criterion is met. A different error
message is not progress.

## Loop detection

Stop when any of these is true, without waiting for a cap:

- The same test has failed three times with the same error.
- You have reverted your own change twice in the same task.
- A fix makes a previously passing test fail, and fixing that one breaks the first.
- You are about to weaken a test, skip a test, update a snapshot, or disable a rule. Always a stop,
  never a step.

## Stop on the environment

- The test suite cannot run at all.
- The node version stops matching `.nvmrc` part way through.
- A pre-commit or pre-push hook fails for a reason outside this change.
- `gh` loses authentication.

## How to stop well

1. Leave the branch and the working tree as they are. Do not revert, reset or clean.
2. Commit only what is already green and coherent. Never commit to make the stop tidy.
3. Say which phase you were in, what triggered the stop, and what you had finished.
4. Run `dt-handoff`, which writes the state to the temp directory for whoever picks it up.
5. If a PR is already open, say so and leave it open. Do not close it to tidy up.
