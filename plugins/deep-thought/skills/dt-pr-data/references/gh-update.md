# Updating the body with the gh CLI

`gh` only. One edit call. The body is composed in full and replaces the old one, so everything worth
keeping must be in the new text before you run it.

## 1. Write the body to a file outside the repo

**Always a quoted heredoc.** PR bodies contain backticks, `{{BRANCH_NAME}}`, `$`, and HTML. An
unquoted heredoc will run the backticks as commands and eat the dollar signs.

```bash
BODY=$(mktemp -t pr-body)
cat > "$BODY" <<'PRBODY'
## Summary

Race pills in the meetings row now scroll by click and drag, in all three racing verticals.

The row borrowed the tag-list styles but not the component that owns the drag behaviour, so it
scrolled by wheel only.

## Links

- **Related Designs:** <a href="LINK_TO_FIGMA" target="_blank">Figma/Designs</a>
- **Jira:** <a href="https://leovegas.atlassian.net/browse/TS-42907" target="_blank">Ticket</a>
PRBODY
```

Note the quoted delimiter (`<<'PRBODY'`, not `<<PRBODY`). Never write the body into the repo working
tree, and never pass it inline with `--body "..."`.

## 2. Sanity-check the text before it goes out

First, if you have not already run `dt-unslop` over the fields, do it now. The greps below check the
two rules a heredoc and a markdown table break most often, so they are worth running even after the
pass.

Run these against the file, and fix rather than post:

```bash
grep -nE '—|–| -- ' "$BODY"          # must print nothing: no em dashes
grep -c '' "$BODY"                    # line count, a sanity check on size
grep -nE '^#{1,4} ' "$BODY"           # every template heading still present, in order
grep -nE '\{\{[A-Z_]+\}\}' "$BODY"    # placeholders you meant to fill but did not
```

Then check by eye:

- Every heading from the template is present, spelled and ordered as the template has it.
- No paragraph runs longer than two lines.
- A blank line separates every pair of paragraphs.
- Existing images, videos, attachment markup, and filled links survived.
- Lists are one line per item and parallel in form.

## 3. Update

```bash
gh pr edit <pr> --repo <owner>/<repo> --body-file "$BODY"
```

One call. If it fails, read the error and fix the input; do not retry with a different mechanism.

## 4. Verify

```bash
gh pr view <pr> --repo <owner>/<repo> --json body -q .body | head -40
gh pr view <pr> --repo <owner>/<repo> --json url -q .url
```

Confirm the body on GitHub matches what you intended, and that the headings are all there. Report the
URL to the user.

## 5. If it went wrong

GitHub keeps no history of PR bodies. The only copy of the previous text is the one the gather script
printed between `<<<BODY_BEGIN>>>` and `<<<BODY_END>>>`. To restore it, write that text back the same
way, with a quoted heredoc, and run one more `gh pr edit --body-file`.

This is why the old body must be in your output before you update, and why a body containing
substantive human prose gets a question first.

## Never

- `gh pr edit --title`, `--add-label`, `--remove-label`, `--add-reviewer`, `--add-assignee`,
  `--milestone`, `--base`. Body only.
- `gh pr merge`, `gh pr close`, `gh pr ready`, `gh pr review`, `gh pr comment`.
- Editing a PR that belongs to someone else, or a merged or closed PR, without asking first.
- Committing, pushing, or touching the working tree. This skill edits a description, nothing else.
- Writing the body file inside the repo.
