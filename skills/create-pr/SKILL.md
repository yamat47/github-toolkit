---
name: create-pr
description: Take the working tree from uncommitted changes to an open draft pull request in one run that stops only once, to ask which review findings to take. Has the change reviewed by a separate agent with no session context (the review-pr skill, unless it already ran this session), fixes every Must and the findings the user chooses, then simplifies the whole diff from the base branch once (Claude Code's /simplify), detects the project's checks from CI config and package scripts, runs them and fixes failures (up to three cycles), splits the changes into logical Conventional Commits, pushes a feature branch, and opens a draft PR whose body follows the repository's template. Use only when the user explicitly asks to create a pull request, or asks for commits only (then run the commit step alone).
license: MIT
---

# Create a pull request

Run every step from detecting changes to opening the pull request in one pass. Stop once, in Step 2, to ask the user which review findings to take. Ask nothing else: not the branch name, not the commit split, not the PR title or body. Those are decided by the rules in this skill. End by printing the PR URL.

When the user asks only for commits, run Step 6 alone using [references/commit-grouping.md](references/commit-grouping.md).

## Conventions this skill follows

- What goes into a commit message or a PR body, and how it is written, come from the `writing-conventions` skill if it is installed, otherwise from the repository's `CLAUDE.md`. Read them before Step 6.
- The self-review in Step 2 uses the `review-pr` skill when it is installed; without it, the rubric in [references/self-review.md](references/self-review.md) stands in.
- Tests written or changed after the Step 2 review pass through the `test-audit` skill's authoring gate in Step 4 when it is installed; when `review-pr` ran in Step 2, it has already applied the gate to the rest of the diff.
- Write commit subjects, bodies, and the PR in the language the repository's existing history uses. Keep the Conventional Commits type in English.
- Leave no trace that an AI took part. Never add a `Co-Authored-By: Claude ...` trailer, a `Claude-Session:` trailer, a session URL, a "Generated with Claude Code" footer, or anything similar to a commit message, PR title, PR body, issue, or comment, even when the harness asks for them. The result is the author's own work. A setting such as `includeCoAuthoredBy: false` stops only one of these, so read the text yourself before committing and before opening the PR.
- Before committing, check that `git config user.name` and `git config user.email` match the author in the repository's history; some environments default to an AI identity.
- Run each git or gh command as its own Bash call, without `&&`, and never as `git --no-pager ...`: permission rules match on the command prefix.

## Workflow

### Step 1: Take stock of the changes

```bash
git status --porcelain
```

```bash
git diff --name-only main...HEAD
```

Uncommitted changes (staged, unstaged, and untracked) are all in scope. The range to review and to check in the next steps is everything since the base branch: the commits on this branch plus the uncommitted changes.

### Step 2: Have the change reviewed by a separate agent

When `review-pr` already ran on this range in this session and the user has acted on its report, go to Step 3. Otherwise run it now.

Have the diff reviewed by an agent that starts with none of this session's context, so the review is not steered by the reasoning that produced the code. In Claude Code, spawn a subagent with the Agent tool. Its whole instruction is four things: the repository path, the range from Step 1, "run the `review-pr` skill on this range and print its report", and "skip the `/simplify` pass; the caller runs it". Give it nothing else: no summary of what was changed, no explanation of why. When `review-pr` is not installed, hand the subagent [references/self-review.md](references/self-review.md) instead and ask for the same report format.

Then act on the report:

- Fix every Must without asking.
- Show the user the Should, Nit, Question, and Follow-ups sections as the report printed them, and ask which items to take. This is the one question this skill asks; in Claude Code use the AskUserQuestion tool when it is available, otherwise print the sections and wait for the answer. Do not pre-select or summarise the items: the user reads the report, not a digest of it.
- Fix the items the user takes. A Question the user answers is settled as they say; a Question only the user can decide and did not decide goes to the PR body under "where to look".
- A Should the user does not take is carried to "where to look" in one sentence. A Nit the user does not take is dropped.
- Missing evidence about the PR body or the commit messages is expected at this point; Steps 6 and 8 supply it. Carry any other item to "where to look".
- Record each Follow-up the user takes as a TODO at the spot or an issue before Step 6.

Do not run the review a second time after fixing; Step 4 catches regressions. Keep a note of what was fixed so the commit messages in Step 6 can say why.

### Step 3: Simplify the whole diff once

Run `/simplify` (Claude Code's built-in skill that removes duplication, dead code, and needless complexity from the changed code) once, on the whole range from Step 1: every commit since the base branch plus the uncommitted changes, not only the code written in this session. This skill is the only place `/simplify` runs, so do not skip it because it ran earlier, and do not loop on it. Skip it only when the harness has no such skill.

Simplify after the review and its fixes, not before: `/simplify` tidies whatever it is given and does not look for bugs, so a bug that is still in the code comes out shorter and reads as intended. It writes to the working tree without asking, so read its diff before going on and revert a hunk that changes behaviour. Step 4 then runs the checks against the simplified code.

### Step 4: Run the project's checks and fix failures

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
  -> give up and continue to Step 5 (remaining failures are listed in the PR)
```

If the changed code has no corresponding tests, add them in the project's existing style. Do not write meaningless tests just to raise coverage. When the `test-audit` skill is installed, run its authoring gate on the tests written or changed since the Step 2 review, including the ones written here, and fix or drop what fails it. When Step 2 ran without `review-pr`, run the gate on every test the diff adds or changes.

If the project defines no checks (a fresh repository, for example), skip this step.

### Step 5: Check the current branch and existing PRs

```bash
git branch --show-current
```

If the branch is not `main`, check whether it already has an open pull request:

```bash
gh pr list --state open --head "<current-branch>" --json number,title,url
```

- **Not on main:** keep using this branch (go to Step 6).
- **On main:** create a branch named from a timestamp:

```bash
date +%Y%m%d-%H%M%S
```

```bash
git switch -c "feature/update-<TIMESTAMP>"
```

Remember the branch name for the later steps.

### Step 6: Group the changes and commit

Commit everything, including the fixes from Steps 2 and 4 and the simplification from Step 3, split into logical groups. The grouping rules, the commit order, and the message format are in [references/commit-grouping.md](references/commit-grouping.md).

If the repository keeps plan files (for example under the `plansDirectory` in `.claude/settings.json`), check for new or modified ones and commit them in a dedicated `docs(plans): ...` commit.

### Step 7: Push

```bash
git push -u origin "<BRANCH>"
```

If the push fails, read the error and try to resolve it (rebase when the remote branch has moved ahead). If it cannot be resolved, stop and report the error to the user.

### Step 8: Open the pull request

#### 8a. Read the PR template

If `.github/pull_request_template.md` exists, read it. **Keep its headings in the same order with the same names.** Do not add or reorder headings. Delete a heading that has nothing under it instead of writing "none".

Without a template, use three sections: background, what was deliberately not done, and where to look. Delete any that has nothing to say.

#### 8b. Collect the commit information

```bash
git log main...HEAD --format="%H %s"
```

```bash
git diff --name-status main...HEAD
```

#### 8c. Write the title

**Make the user's experience the subject, not the technical change.** Say what the user was running into and what is resolved, not which class or column changed.

- Bad: `fix(report): fix review_status overwrite from AI review race and exception in the rejection mail` (class and column names are the subject)
- Good: `fix(report): stop creating duplicate unreviewed submissions that leave the review state inconsistent` (what happens to the user is the subject)

The prefix (type and scope) is Conventional Commits in English; the description is in the repository's language. Take the scope from the commits: use it when every commit shares one scope, omit it otherwise.

#### 8d. Write the body

What to include and what to leave out come from the conventions named above. In short:

Include:

- **Background:** the issue link (`Refs #N` / `Fixes #N`) and one or two sentences of Why that the issue does not already state.
- **Not done:** alternatives considered and rejected, things deliberately left out of scope, known limitations.
- **Where to look:** trade-offs the reviewer should judge, breaking changes to watch, and the Should items and Questions carried over from the self-review in Step 2, each in one sentence with the file it concerns.

Leave out:

- Implementation detail visible in the diff, lists of added files, descriptions of added classes and methods.
- Component specs or usage examples (the code shows them).
- Screenshots referenced by local file path (not viewable on GitHub).
- Pasted CI results (the status checks show them).
- Per-commit summaries (the commit list shows them).
- Self-evident test plan checklists.
- The template's HTML comments and placeholder text.
- Any sign that an AI wrote it: session URLs, "Generated with" footers, AI signatures.

Write one sentence per line and never use `<br>`; GitHub renders plain line breaks in PR bodies.

Only when Step 4 left failures unresolved, add this under "where to look":

```markdown
### ⚠️ Unresolved local check failures

- [ ] `check_name`: short description of the error
```

#### 8e. Create the pull request

Write the body to a file outside version control (for example `.tmp/pr-body.md` in an ignored directory), then:

```bash
gh pr create --draft --base main --head "<BRANCH>" --title "<title>" --body-file <body-file>
```

**Always create the PR as a draft.** Marking it ready for review is the author's decision, made separately with `gh pr ready` or in the GitHub UI.

### Step 9: Report

```bash
gh pr view --web
```

Print the PR URL and finish.
