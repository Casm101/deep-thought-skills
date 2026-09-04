# Opening the PR

`gh` only. Never a GitHub MCP server or gateway tool.

## The base

Name it explicitly with `--base`. Never rely on the default, because `gh` picks the repository default
and plenty of teams merge feature work into a release branch instead.

Read what the repo says before deciding. The preflight lists the release and branching docs it found,
along with any workflow whose name mentions branches, backmerges or releases. A repo with a
`RELEASE-BRANCHING.md` has an opinion, and it is usually stricter than the default suggests.

When the base is anything other than the repo default, confirm it with the user before you push.

## The title

Copy the shape of the repo's recent merged PRs, which the preflight prints.

Most conventions want the ticket key and then an imperative summary of the behaviour:

```
TS-42830 Show combination forecast and tricast bets correctly in My Bets
```

The title says what the change does for whoever uses the product. Not what you did to the code, not
the branch name, and not a list of the commits. Keep it under about seventy characters, no trailing
full stop.

Where the branch has no ticket key, say so in the title the way the repo does, for example a
`[NO-TICKET]` prefix if that is what the log shows.

## The body

Seed it from the repo's own template so no section goes missing:

```bash
gh pr create \
  --repo <owner>/<repo> \
  --base <base> \
  --head <branch> \
  --title "TS-42830 Show combination forecast and tricast bets correctly in My Bets" \
  --body-file .github/PULL_REQUEST_TEMPLATE.md
```

Leave the template's placeholders alone at this point. `dt-pr-data` fills them next, and it does a
better job because it reads the diff, the commits and the ticket first.

Where the repo has no template, pass a one line body saying what the change does, and let
`dt-pr-data` build the structure from how merged PRs are written.

## Draft or ready

Ready by default. Open as a draft only when the user asked for one, or when CI is red or the work is
knowingly incomplete, in which case ask first.

```bash
gh pr create ... --draft
```

Never flip an existing PR between draft and ready. That is the author's call and it sends
notifications.

## When a PR already exists

Do not create another. Push, then report which PR it is:

```bash
gh pr list --repo <owner>/<repo> --head <branch> --state open --json number,url,isDraft
```

Hand its number to `dt-pr-data` if the description needs filling. If the existing PR is closed rather
than open, ask before opening a new one, because a closed PR usually means somebody decided
something.

## After it opens

```bash
gh pr view <number> --repo <owner>/<repo> --json url,baseRefName,isDraft
gh pr checks <number> --repo <owner>/<repo>
```

Report the URL, the base, and whether checks had started. Then stop.

## Never

- `git push --force` or `--force-with-lease`
- `git push --no-verify`
- `gh pr merge`, `gh pr close`, `gh pr ready`, `gh pr review`
- `--reviewer`, `--assignee`, `--label`, `--milestone`, unless the user named them
- Opening a PR from the default branch, or from a branch with nothing committed
- Editing the description here. That is `dt-pr-data`
