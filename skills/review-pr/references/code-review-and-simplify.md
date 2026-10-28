# `/code-review` and `/simplify` as readers

Claude Code ships two bundled skills that read a diff the way this skill does. This file says how `review-pr` uses them without giving up its contract: it prints a report, it writes nothing, and it posts nothing. The facts below are from the Claude Code documentation (`code-review-local`, `commands`) as of v2.1.2xx; when the harness behaves differently, the harness wins.

| Skill | What it does | What it writes |
|---|---|---|
| `/code-review [level] [flags] [target]` | Finds correctness bugs in the target; depending on the model and the effort level it also reports reuse, simplification, and efficiency cleanups. Runs as a background subagent in a terminal session and in the foreground in a `-p` run. `/review` is an alias | Nothing without `--fix` |
| `/simplify [target]` | Four agents in parallel look for reuse of existing helpers, simplification, efficiency, and the right level of abstraction, and apply what they find. It does not look for bugs | The working tree, with no flag to report only |
| `/security-review` | Reads the diff against the origin's default branch for injection, authentication, and data exposure | Nothing |

Both readers are started at the end of Step 1 and read at Step 4. Their output is a list of candidates and nothing more: every item goes through [verification.md](verification.md) like a candidate of your own, and one finding covers every location of a pattern whoever found it first. When the harness has neither skill, skip this file; the Verdict says the review ran without them.

## Start `/code-review`

Pass the same target this skill resolved, so both readers see the same lines:

| Target as given | What to type |
|---|---|
| A PR number or URL | `/code-review <level> <number>` |
| A branch | `/code-review <level> <default-branch>...<branch>` |
| A commit range | `/code-review <level> <range>` |
| Nothing | `/code-review <level>` (the current branch plus uncommitted changes) |

Always type the level. Without one, `/code-review` reuses the last level typed, even in an earlier session, so two runs of this skill would read at different depths.

| Change | Level |
|---|---|
| Routine: documentation, configuration, a rename, tests only, a change the codebase already has a pattern for | `medium` |
| Touches transactions, authentication or authorization, money, concurrency or jobs, a data migration or backfill, cryptography, a CI workflow that handles secrets, or code nobody on the team knows | `high` |
| The user asks for few findings they can trust | `low` |
| `xhigh`, `max` | Only when the user asks; `max` starts many subagents |

Never pass `--fix` (it edits the tree), `--comment` (it posts to the PR), or `ultra` (it uploads the change to a cloud review). Leave `--max-findings` alone; Step 4 drops what does not hold rather than capping the list.

When the diff touches authentication, authorization, secrets, or request parsing, also run `/security-review` and treat its output the same way. It reads the current branch against the origin's default branch, so it fits the "nothing" and "branch" targets only.

## Run `/simplify` in a copy

`/simplify` rewrites whatever tree it runs in, so it never runs in the target's working tree. It runs in a throwaway worktree at the target's head, and the diff it leaves there is its proposal.

Skip this part when no changed file is code (documentation, configuration, lock files, and workflow YAML only), or when the harness has no `/simplify` or no way to run a subagent in another directory.

1. Create the copy. `DIR` is a new directory outside the repository.

   ```bash
   git worktree add --detach "$DIR" <head>
   ```

   `<head>` is the branch for a branch target, the end of the range for a range target, `FETCH_HEAD` after `git fetch origin pull/<number>/head` for a PR target, and `HEAD` for the "nothing" target. For the "nothing" target, also copy the uncommitted changes: `git diff HEAD | git -C "$DIR" apply`, then copy each file `git ls-files --others --exclude-standard` lists into the same path under `$DIR`.

2. Run `/simplify` there through a subagent (in Claude Code, the Agent tool). Its whole instruction is three things: the worktree path, the target as the table above writes it for `/code-review`, and "run `/simplify` there on this target, then stop; commit nothing". Give it nothing else, so its agents read the code and not your opinion of it.

3. Read the proposal and remove the copy.

   ```bash
   git -C "$DIR" add -A
   ```

   ```bash
   git -C "$DIR" diff --cached
   ```

   ```bash
   git worktree remove --force "$DIR"
   ```

## From a `/simplify` hunk to a finding

Group the hunks by intent: one helper reused, one guard removed, one expression rewritten. Each group is one candidate with ASIS the code in the diff, TOBE the rewrite, and Problem what the current code duplicates or carries for nothing.

Keep a candidate only when:

- The behaviour is the same for every input you can name. `/simplify` does not check for bugs, and a rewrite that changes behaviour is not a simplification. When the new behaviour is the right one, the original code is a correctness finding at its own severity, and the hunk is not reported as a simplification.
- The repository's rules do not choose the current form, and a configured linter would not make the change itself.
- No Must or Should changes the same lines. Those lines will be rewritten by the fix; simplifying them comes after, as "After the report" in `SKILL.md` says.

Severity: Should when the rewrite replaces new code with a helper, scope, action, or mechanism the codebase already has, or removes code shown to be dead or a guard the types or constraints already rule out. Nit otherwise.
