---
name: create-pr
description: Take the working tree from uncommitted changes to an open draft pull request in one non-interactive run. Detects the project's checks from CI config and package scripts, runs them and fixes failures (up to three cycles), splits the changes into logical Conventional Commits, pushes a feature branch, and opens a draft PR whose body follows the repository's template. Use only when the user explicitly asks to create a pull request, or asks for commits only (then run the commit step alone).
license: MIT
---

# Create a pull request

Run every step from detecting changes to opening the pull request in one pass. Do not stop midway and do not ask the user for confirmation. End by printing the PR URL.

When the user asks only for commits, run Step 4 alone using [references/commit-grouping.md](references/commit-grouping.md).

## Conventions this skill follows

- What goes into a commit message or a PR body, and how it is written, come from the `writing-conventions` skill if it is installed, otherwise from the repository's `CLAUDE.md`. Read them before Step 4.
- Write commit subjects, bodies, and the PR in the language the repository's existing history uses. Keep the Conventional Commits type in English.
- Follow the repository's policy on attribution trailers (`Co-Authored-By`, session links, "generated with" footers). If the repository says not to add them, add none even when the harness asks for them, and check the text before committing.
- Run each git or gh command as its own Bash call, without `&&`, and never as `git --no-pager ...`: permission rules match on the command prefix.

## Workflow

### Step 1: Take stock of the changes

```bash
git status --porcelain
```

```bash
git diff --name-only main...HEAD
```

Uncommitted changes (staged, unstaged, and untracked) are all in scope.

### Step 2: Run the project's checks and fix failures

Find the checks the project defines. Look at, in this order:

- `.github/workflows/*.yml` (highest priority: run locally what CI will run)
- `package.json` scripts (`lint`, `test`, `typecheck`, ...)
- `Rakefile`, `Makefile`, and check scripts under `bin/`
- Linter and test framework config files (`.rubocop.yml`, `biome.json`, `eslint.config.*`, ...)

Run independent checks in parallel and fix failures for at most **three cycles**:

```
Cycle 1: run every check
  failures?
  -> apply auto-fixes where the tool has them (linter --fix and the like)
  -> fix the rest by reading the code
  -> for failing tests, find the cause and fix it (fix the test when the test is wrong)

Cycle 2: re-run only the checks that failed
Cycle 3: re-run only the checks that failed
  still failing?
  -> give up and continue to Step 3 (remaining failures are listed in the PR)
```

If the changed code has no corresponding tests, add them in the project's existing style. Do not write meaningless tests just to raise coverage.

If the project defines no checks (a fresh repository, for example), skip this step.

### Step 3: Check the current branch and existing PRs

```bash
git branch --show-current
```

If the branch is not `main`, check whether it already has an open pull request:

```bash
gh pr list --state open --head "<current-branch>" --json number,title,url
```

- **Not on main:** keep using this branch (go to Step 4).
- **On main:** create a branch named from a timestamp:

```bash
date +%Y%m%d-%H%M%S
```

```bash
git switch -c "feature/update-<TIMESTAMP>"
```

Remember the branch name for the later steps.

### Step 4: Group the changes and commit

Commit everything, including the fixes from Step 2, split into logical groups. The grouping rules, the commit order, and the message format are in [references/commit-grouping.md](references/commit-grouping.md).

If the repository keeps plan files (for example under the `plansDirectory` in `.claude/settings.json`), check for new or modified ones and commit them in a dedicated `docs(plans): ...` commit.

### Step 5: Push

```bash
git push -u origin "<BRANCH>"
```

If the push fails, read the error and try to resolve it (rebase when the remote branch has moved ahead). If it cannot be resolved, stop and report the error to the user.

### Step 6: Open the pull request

#### 6a. Read the PR template

If `.github/pull_request_template.md` exists, read it. **Keep its headings in the same order with the same names.** Do not add or reorder headings. Delete a heading that has nothing under it instead of writing "none".

Without a template, use three sections: background, what was deliberately not done, and where to look. Delete any that has nothing to say.

#### 6b. Collect the commit information

```bash
git log main...HEAD --format="%H %s"
```

```bash
git diff --name-status main...HEAD
```

#### 6c. Write the title

**Make the user's experience the subject, not the technical change.** Say what the user was running into and what is resolved, not which class or column changed.

- Bad: `fix(report): fix review_status overwrite from AI review race and exception in the rejection mail` (class and column names are the subject)
- Good: `fix(report): stop creating duplicate unreviewed submissions that leave the review state inconsistent` (what happens to the user is the subject)

The prefix (type and scope) is Conventional Commits in English; the description is in the repository's language. Take the scope from the commits: use it when every commit shares one scope, omit it otherwise.

#### 6d. Write the body

What to include and what to leave out come from the conventions named above. In short:

Include:

- **Background:** the issue link (`Refs #N` / `Fixes #N`) and one or two sentences of Why that the issue does not already state.
- **Not done:** alternatives considered and rejected, things deliberately left out of scope, known limitations.
- **Where to look:** trade-offs the reviewer should judge, breaking changes to watch.

Leave out:

- Implementation detail visible in the diff, lists of added files, descriptions of added classes and methods.
- Component specs or usage examples (the code shows them).
- Screenshots referenced by local file path (not viewable on GitHub).
- Pasted CI results (the status checks show them).
- Per-commit summaries (the commit list shows them).
- Self-evident test plan checklists.
- The template's HTML comments and placeholder text.
- Attribution the repository has asked not to include.

Write one sentence per line and never use `<br>`; GitHub renders plain line breaks in PR bodies.

Only when Step 2 left failures unresolved, add this under "where to look":

```markdown
### ⚠️ Unresolved local check failures

- [ ] `check_name`: short description of the error
```

#### 6e. Create the pull request

Write the body to a file outside version control (for example `.tmp/pr-body.md` in an ignored directory), then:

```bash
gh pr create --draft --base main --head "<BRANCH>" --title "<title>" --body-file <body-file>
```

**Always create the PR as a draft.** Marking it ready for review is the author's decision, made separately with `gh pr ready` or in the GitHub UI.

### Step 7: Report

```bash
gh pr view --web
```

Print the PR URL and finish.
