# Writing and posting the replies

`gh` only. No GitHub MCP or gateway tool. Nothing here runs before the user has approved that
specific reply.

## Style

`dt-unslop` is the authority on the general rules, and Phase 4 runs it over every draft. These are the
additions that a reply to a reviewer needs.

Same house style as the review skill, because it is the same PR and the same readers.

- **No em dashes. Ever.** Do not type `—`, `–`, or ` -- ` in a reply. Use a comma, a semicolon, a
  colon, brackets, or two sentences.
- **More than one paragraph means a blank line between them** (`\n\n` in a JSON body, a real blank
  line in a `--body-file`). Two distinct thoughts should not run together.
- **Plain, human words.** Reach for a technical term only when it is the precise name for the thing.
  "the user sees an empty list" beats "the error state is unhandled". "this runs twice" beats "this
  results in a duplicate invocation".
- **Short.** An acknowledgement is one line. A disagreement is two or three sentences with a citation.
  Go longer only when the mechanism genuinely needs showing, and then keep it to a short paragraph
  plus the citation.
- **Cite `file:line`** for anything factual. It is what turns a claim into something the reviewer can
  check in five seconds.
- No filler openers, no exclamation marks, no "Great catch!!". One "good catch" per review, at most,
  and only when it was.
- Never characterise the reviewer or their attention. Address the claim.

## Shapes by verdict

**AGREE-FIX.** One line. Do not explain the fix in the thread; the fix will speak for itself.

> Good catch, this does lose pins on deploy. Adding a `0 -> 1` migration that seeds from the old key.

**PARTLY-RIGHT.** Concede first, then the different remedy and its reason.

> Agreed the selector goes stale, that part is real.
>
> Going with the Zustand hooks in both consumers rather than a Redux invalidation signal, since
> `CONVENTIONS.md` puts shared UI state in Zustand.

**ALREADY-DONE.** Point at the current state, no triumph.

> This changed in `a1aad94`, the spread order is now new-entry-last. Current code is at
> `store.ts:56` if you want another look.

**AGREE-OUT-OF-SCOPE.** Agree, name the boundary, propose the next step.

> Fair point, and it predates this branch. Keeping this PR to the Zustand move; happy to raise a
> follow-up for the persist cleanup.

**NEEDS-INFO.** One specific question with the options in it.

> Do you mean the tab should stay on pinned when the list empties, or redirect immediately? Happy
> either way, just want the behaviour you expect.

**NIT-DECLINE.** Warm, short, door open.

> Leaving the two passes here for readability, but no strong feelings if you'd rather I fold them.

**DISAGREE.** Evidence first, then the conclusion, then the offer.

> `PinMarketButton` only calls `setPinnedMarket` when `isActive` is false (`PinMarketButton.tsx:34`),
> so the re-pin path this describes is not reachable from the UI.
>
> Happy to guard it anyway if you'd rather not rely on the caller.

That last sentence matters. A disagreement that ends with an offer resolves; one that ends with a
verdict argues.

## Pre-send checks

Read every reply body once more and fix any that fail:

1. It has been through `dt-unslop`. If you rewrote this reply after the pass, run it again.
2. No `—`, `–`, or ` -- `, and a blank line between paragraphs. JSON bodies break these two most often.
3. Every factual claim carries `file:line`.
4. Nothing about the reviewer, only about the claim.
5. A disagreement ends with an offer or a question, not a full stop on your own verdict.

## Posting

### Reply inside an existing thread

Use the comment id printed for that thread by `pr-feedback.sh`. Write the body to a scratchpad file
(never into the repo) to avoid shell quoting problems:

```bash
gh api --method POST \
  "repos/<owner>/<repo>/pulls/<pr>/comments/<comment_id>/replies" \
  --input /path/to/reply.json
```

`reply.json`:

```json
{ "body": "Good catch, this does lose pins on deploy.\n\nAdding a `0 -> 1` migration that seeds from the old key." }
```

Reply to the **first** comment id in the thread. Post one reply per thread, covering that thread's
points in the order they were raised, rather than several replies in the same thread.

### A standalone comment on the PR

For points that are not anchored to a thread (a review summary body, a general comment, or a wrap-up
of what you are doing across several threads):

```bash
gh pr comment <pr> --repo <owner>/<repo> --body-file /path/to/comment.md
```

One comment, not several. If you are answering a long review write-up, mirror its structure with
short headings so each of their points has a visible answer.

### Verify

```bash
gh api "repos/<owner>/<repo>/pulls/<pr>/comments" --paginate \
  -q '.[] | select(.user.login == "<you>") | "\(.id) \(.path):\(.line) \(.body[0:60])"' | tail -10
gh pr view <pr> --repo <owner>/<repo> --json comments -q '.comments[-1].url'
```

Report to the user: what was posted, where, and the URLs. If a reply failed, say which one and why,
and do not retry a different way without asking.

## Never

- Post anything the user has not approved, or reword an approved reply after approval.
- Resolve, minimise, hide, or edit a review thread or anyone's comment. Resolving is the author's
  call, done in the UI, after the fix lands.
- Approve, merge, close, or re-request review on the PR.
- Push commits, or implement the plan. This skill plans and replies; that is all.
- Answer a review on a PR that is not the user's own.
