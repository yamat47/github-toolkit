# Structured output

Some callers run this skill non-interactively and ask for JSON (for example with Claude Code's `--json-schema`). The caller's schema wins; this file says how the Markdown sections map onto it so every caller gets the same content.

| Section | Field |
| --- | --- |
| Verdict, first word or phrase | `verdict`: `approve`, `approve_with_requests`, or `request_changes` |
| Verdict, the rest | `overall`: the sentence that decided it, and what is to be done before merge |
| Comments | `comments[]`, one per comment, in the order of the files in the diff |
| Aside | `aside[]`, one string per line |
| For later | `follow_ups[]`, one string per line |

Each comment:

| Field | Value |
| --- | --- |
| `kind` | `question`, `request`, or `nit` |
| `deferrable` | `true` when the heading says deferrable |
| `path` | The file, relative to the repository root. Always present |
| `start_line`, `end_line` | Line numbers in the new version of the file, or `null` for a comment anchored to the file |
| `title` | The first line of the comment |
| `body` | The whole comment as it will be posted, including the first line |
| `suggestion` | The replacement code when the comment carries a `suggestion` block, else `null` |
| `source` | `verification` when the comment carries a Must from `review-pr`, else `feedback` |

A Must from `review-pr` becomes a `request` with `source: verification`. A Should, a Nit, or a Question from the report is posted only when Step 4 raises the same point, and then as this skill's own comment with `source: feedback`.
