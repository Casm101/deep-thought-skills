# Posting the review with the gh CLI

`gh` only. No GitHub MCP or gateway tool, for reads or writes.

Everything here runs **after** the user has approved the specific findings.

## 0. Facts that decide the payload

- **`event` is only ever `COMMENT` or `APPROVE`.** `REQUEST_CHANGES` is not used by this skill.
  Any finding that is not a nit means `COMMENT`; nits only (or nothing) means `APPROVE` with the
  comments attached. See the verdict rule in SKILL.md.
- **You cannot approve your own PR.** GitHub returns 422. If the PR author is the current `gh`
  user and the verdict would be `APPROVE`, send `COMMENT` instead and say in the summary body that
  the nits are non-blocking and the PR looks good. Check the author with:
  `gh pr view <n> --json author -q .author.login` against `gh api user -q .login`.
- **A comment must anchor to a line that is part of the diff** for the head commit, or the whole
  request is rejected (422, "line must be part of the diff"). If in doubt, anchor to a line you can
  see with a `+` or a context marker in the hunk, or make it a file-level comment.
- `side: "RIGHT"` is the default and numbers lines in the head version. Use it for added and context
  lines. `side: "LEFT"` numbers the base version, so use it only to comment on a removed line.
- Omitting `event` leaves the review **pending** (a draft only you can see). Always pass `event`.

Read hunk headers to get line numbers: `@@ -12,7 +12,9 @@` means the new-file (RIGHT) side of that
hunk starts at line 12; count forward through the hunk, skipping `-` lines.

## 1. Build the payload as a file

Never hand-quote JSON into a shell command. Write it with the Write tool, then pass `--input`.
Write to the session scratchpad, not into the repo.

```json
{
  "commit_id": "<head sha from pr-context.sh>",
  "event": "COMMENT",
  "body": "Reviewed against CONVENTIONS.md and the test patterns in this package. 1 blocker, 2 worth fixing, 1 nit that is non-blocking. Details inline.",
  "comments": [
    {
      "path": "src/features/bets/useBetSlip.ts",
      "line": 48,
      "side": "RIGHT",
      "body": "Nothing handles `isError`, so if the request fails the user just sees an empty slip.\n\nThe existing `<ErrorPanel/>` covers this."
    },
    {
      "path": "src/features/bets/BetCard.tsx",
      "start_line": 22,
      "line": 26,
      "side": "RIGHT",
      "start_side": "RIGHT",
      "body": "nit: this walks the list twice; one `reduce` would do it.\nNon-blocking, no need to resolve."
    },
    {
      "path": "src/features/bets/index.ts",
      "subject_type": "file",
      "body": "These new exports cross the package boundary that `docs/CONVENTIONS.md` sets out.\nRe-exporting from the package entry keeps it inside."
    }
  ]
}
```

Note the shapes in that example: `\n\n` where the first comment breaks into two paragraphs, `\n`
where the nit is one paragraph on two lines, and no em dash anywhere in any body.

- Single line: `path`, `line`, `side`, `body`.
- Line range: add `start_line` and `start_side` (`start_line` < `line`).
- Whole file: `subject_type: "file"` with no line fields.
- Keep the summary `body` short: what you reviewed against, the counts, and nothing else. The
  detail belongs inline. When any finding is a nit, state in the summary that those are
  non-blocking, so the author knows the count they actually have to act on.
- Every nit comment carries its own release phrase (`non-blocking`, `no need to resolve`) in the
  body. A review whose findings are all nits is `event: "APPROVE"`.

### Check the text before you send it

Read every `body` string in the payload once more, and fix any that fail:

1. It has been through `dt-unslop`. If you cannot say when, run it now.
2. No `—`, no `–`, no ` -- `. Replace with a comma, semicolon, colon, brackets, or two sentences.
3. Two paragraphs means `\n\n` between them, not `\n`.
4. Roughly 30 words, two lines, unless the finding truly needs more.
5. Each nit says it is non-blocking.

Checks 2 and 3 are the two unslop rules a JSON payload breaks most often, so they are worth running
again by eye even after the pass. All five apply to every suggestion reply body in the next step.

## 2. Create the review in one call, with all comments

```bash
gh api --method POST "repos/<owner>/<repo>/pulls/<number>/reviews" \
  --input /path/to/review.json
```

Capture the returned review `id` and `html_url`:

```bash
gh api --method POST "repos/<owner>/<repo>/pulls/<number>/reviews" \
  --input /path/to/review.json -q '{id, html_url, state}'
```

If it fails with 422 on a line, fix that one comment's anchor (or convert it to `subject_type:
"file"`) and retry the whole call. Do not fall back to posting the comments one by one. That spams
the author with N notifications.

## 3. Add suggested fixes as threaded replies

Get the comment IDs created by this review:

```bash
gh api "repos/<owner>/<repo>/pulls/<number>/comments" --paginate \
  -q '.[] | select(.pull_request_review_id == <review id>) | "\(.id)\t\(.path):\(.line)"'
```

Then, for each finding that has a concrete drop-in fix, reply to its comment:

```bash
gh api --method POST \
  "repos/<owner>/<repo>/pulls/<number>/comments/<comment id>/replies" \
  --input /path/to/reply.json
```

`reply.json`:

```json
{
  "body": "```suggestion\n  if (isError) return <ErrorPanel onRetry={refetch} />;\n```"
}
```

Rules for a `suggestion` block:

- Its content **replaces the comment's exact line range**, so it must contain the complete
  replacement for those lines, with the right indentation, no leading `+`, and no context lines.
- Anchor the parent comment to precisely the lines you intend to replace. To suggest replacing
  three lines, the parent comment needs `start_line`/`line` spanning those three.
- Nothing else in the reply body: just the block, so the "Apply suggestion" button is unambiguous.
- Skip the suggestion when the fix is not a literal line replacement (needs a new import, a change
  in another file, or a design decision). Explain it in prose in the parent comment instead.

After the replies land, confirm one of them renders as an applicable suggestion (fetch the comment
and check the body survived intact). If GitHub does not offer to apply it, delete the reply and put
the block in the parent comment body instead, which always renders:

```bash
gh api --method DELETE "repos/<owner>/<repo>/pulls/comments/<comment id>"
```

## 4. Verify and report

```bash
gh api "repos/<owner>/<repo>/pulls/<number>/reviews/<review id>" -q '{state, body}'
gh api "repos/<owner>/<repo>/pulls/<number>/comments" --paginate \
  -q '[.[] | select(.pull_request_review_id == <review id>)] | length'
```

Report to the user: the review URL, the comment count posted versus approved, and any finding that
had to be re-anchored or downgraded to a file-level comment.

## Useful reads

```bash
gh pr view <n> --json title,body,files,reviewDecision
gh pr diff <n>                       # full diff
gh pr checks <n>                     # CI gates
gh api repos/<owner>/<repo>/pulls/<n>/files --paginate -q '.[].filename'
gh pr view <n> --json reviews -q '.reviews[] | "\(.author.login) \(.state)"'
```

## Never

- `event: "REQUEST_CHANGES"`, or `gh pr review --request-changes`. Not available in this skill.

## Never, without a fresh explicit request from the user

- `gh pr merge`, `gh pr close`, `gh pr edit`, `gh pr ready`
- Pushing commits or applying the fixes yourself. This skill reviews, it does not write the code
- Deleting or editing another person's comments
- Approving a PR that the user has not asked you to approve
