---
name: review-pr
description: Review a pull request, a branch, or the current diff and print the result to the terminal. Routes each changed file to the knowledge skills that are installed (rails-safety, rails-schema-design, rails-idioms, dhh-rails-patterns, api-design, typescript-idioms, vue-patterns, react-patterns, swift-idioms, swift-concurrency, github-actions-workflows, test-audit, writing-conventions) and to the repository's own rules, runs Claude Code's /code-review (report only) and /simplify (in a throwaway copy) as two more readers, checks correctness, data model, design, naming, tests, and PR hygiene, verifies every finding before reporting it, and prints a fixed-heading Markdown report (Verdict, Must, Should, Nit, Question, Follow-ups, Missing evidence). Runs locally, edits nothing, posts nothing. Use when the user asks to review a PR, review a diff or branch, do a code review, or check a change before merge. Accepts a PR number or URL, a branch name, a commit range, or nothing (the current branch against its base).
license: MIT
---

# Review a pull request

This skill is the procedure. The knowledge about what is wrong in Rails code, a schema, or a comment lives in other skills and in the repository being reviewed; this skill decides what to read, in what order, how to check a finding before reporting it, and how to print the result. It never posts to GitHub and never edits the target. The caller decides what to do with the printed report.

The report states what is verifiably wrong and what the PR should show. What the reviewer would say to the author, including the questions whose answer only the author has, is the job of `review-feedback`, which, when it is installed, runs this skill after its own reading of the diff and builds on the report. When the user asks for comments to post rather than a report, use that skill.

Claude Code's `/code-review` and `/simplify` take part as two more readers, never as writers. `/code-review` runs in report-only mode on the same target. `/simplify` rewrites whatever tree it is given, so it runs in a throwaway copy of the target, and the diff it leaves there enters the report as findings instead of reaching the tree. [references/code-review-and-simplify.md](references/code-review-and-simplify.md) has the commands, the effort level to pass, and what keeps a `/simplify` hunk. Neither reader is the review: their output is a list of candidates that Step 4 verifies like any other.

## Target

The target is whatever the user names.

- A PR number or URL: read it with `gh pr view` and `gh pr diff`; the range is the PR's base to its head.
- A branch: the range is `git merge-base <default-branch> <branch>` to the branch tip.
- A commit range: use it as given.
- Nothing: the current branch against its base, including uncommitted changes.

When every hunk only changes a dependency version, SHA, or digest in a manifest or a lock file, the change is a dependency update: it is the job of `review-dependency-bump`. A change to a workflow or a Dockerfile that does more than that stays here. Say so and stop before Step 1.

Run each `gh` and `git` command as its own Bash call so permission rules can match on the command prefix, and issue the calls that do not depend on each other (Step 1 items 1 to 3) together.

## Step 1: Gather context before forming any opinion

1. Read the PR title, body, and commit messages. Note the stated purpose, what the author says was verified, and every linked discussion. Record what is missing for the "Missing evidence" section; [references/verification.md](references/verification.md) lists what each kind of change should show.
2. Read the repository's own rules: `CLAUDE.md`, `AGENTS.md`, every file under `.claude/rules/` whose `paths` match a changed file, the PR template, and the linter configuration. These outrank everything this skill or the knowledge skills say. When the repository has decided against a toolkit rule, the toolkit rule is not a finding.
3. List every changed file, including configuration, CI, generated files, and lock files. Classify each one with the routing table in [references/routing.md](references/routing.md) and load the knowledge skills it names, if they are installed. A file whose purpose cannot be explained from the diff is itself a finding.
4. Read the surrounding code, not only the hunks: the callers of a changed method, the other consumers of a changed enum or endpoint, sibling files that solve the same problem. Most verified findings come from this step.
5. Start the two readers, in the background, as [references/code-review-and-simplify.md](references/code-review-and-simplify.md) describes: `/code-review` on the same target at the effort level the file picks from the changed files, and `/simplify` in a copy of the target. Do not read their output before Step 4. Steps 2 and 3 produce your own candidate list first; with theirs already on the table, those steps would turn into a check of someone else's list. Skip a reader the harness does not have, and note the skip for the Verdict.

When the caller (`review-feedback`) has already read the PR text and the rules and loaded the knowledge skills, do not read or load them again; start at item 4.

## Step 2: Judge the change as a whole

Before reading line by line, answer these questions about the PR.

- Does the codebase already have a mechanism for this? Search for it. Reusing an existing action, helper, or endpoint beats adding a parallel one.
- Is the placement consistent with the sibling code and with the layering the repository declares? A one-off divergence needs a stated reason. "The existing code does it this way" is not a reason on its own; a link to the decision that introduced the pattern is.
- Is the PR one coherent unit? Too small (a single repository method with nothing calling it) and too large (a whole API surface) are both findings, as are unrelated changes mixed in.
- What happens with zero, one, and many records; with nil, an empty string, and an unexpected enum value; when the operation runs twice; when it fails halfway; across a time zone boundary; after a rollback of the migration? Which other flows share the changed method?
- Does the schema change match the business cardinality, and is it separated from the application change?

## Step 3: Review the lines with the knowledge loaded

Apply the loaded knowledge skills and the repository rules to each hunk. For every candidate finding, record the file and line, what the code does now, why that is a problem, and what it should do instead. When the intent is unclear, record a question with the options you see and your recommendation.

When one instance of a pattern is found, search the whole diff for the same pattern and report it once with every location.

For every defensive check, guard clause, or constraint, ask which concrete scenario it guards against. If a database constraint, a type, or the calling code already rules that scenario out, the check is a candidate for removal.

Problems that exist outside the diff are out of scope unless the change makes them worse. Mention them at most as a follow-up.

## Step 4: Verify every finding before it enters the report

Now read the two readers' output and add it to the candidate list. A `/code-review` finding is a candidate with a file and a line, nothing more. A `/simplify` hunk becomes a candidate only under the rules in [references/code-review-and-simplify.md](references/code-review-and-simplify.md), and never for lines a Must or Should will rewrite. When a reader and Step 3 found the same thing, it is one finding.

Go through the candidate list once more, re-read the code around each finding, and drop or downgrade findings using the rules in [references/verification.md](references/verification.md). Keep only findings you can state as a fact or as a precise question.

Assign the severity with the rubric in the same file. Not everything is a Must.

## Step 5: Decide the verdict

- Approve: no Must and no Should; nothing breaks and nothing measurably regresses. Nits stay in the Nit section and need no record.
- Approve with follow-ups: no Must, and at least one Should or Question that needs a fix, an answer, or a follow-up before merge. Every follow-up is recorded (a TODO at the spot or an issue) before merge, and the report says so.
- Request changes: at least one Must, or a design question about the foundations that has to be settled before details are worth discussing.

Say when someone else should look too: a change to a shared schema, a CI workflow, or another team's surface names the kind of owner who should be pulled in.

## After the report

The report is read-only, and the skill stops when it is printed. This is the order for whoever acts on it.

1. Decide what to take. Must is always taken. A Should is fixed or answered with a reason before merge. Nits, Questions, and the simplification findings are the author's choice. This skill does not make the choice; `create-pr` asks the user for it.
2. Fix what was taken, correctness first and simplifications last. The simplification findings were derived from the code before the fixes, so a hunk on a line the fixes rewrote is re-read against the fixed code rather than applied as printed. Nobody runs `/simplify` on the tree: it already ran in the copy, and its proposal is in the report.
3. Then run the project's checks and tests. This is what catches a simplification that changed behaviour.
4. Run this skill again only when step 2 changed a design or a schema. The checks cover the simplification.

`create-pr` follows this order when it calls this skill.

## Output

Print the report in the fixed format described in [references/report-format.md](references/report-format.md). The headings never change, so other tools can read them; a section with nothing to say contains the single line "None." When the caller asks for structured output instead (for example Claude Code's `--json-schema`), map the sections as [references/structured-output.md](references/structured-output.md) describes. Write the findings in the language the repository uses for pull requests, following `writing-conventions` when it is installed. Findings are stated as facts with the fix; questions are stated as questions with options; no praise is mixed into a finding. When a knowledge skill the routing table asked for is not installed, the Verdict section says so, because the review then relied on general knowledge for that area. When `/code-review` or `/simplify` did not run, the Verdict says that too, so the author can run it before merge.
