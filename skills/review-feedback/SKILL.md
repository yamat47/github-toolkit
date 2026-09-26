---
name: review-feedback
description: Write the review comments a human reviewer would post on a code pull request, in that reviewer's stance. Reads the diff before the description, turns what the author has to justify into questions, checks where logic was placed and which way dependencies point, naming, and the prose of comments and the PR body, marks each comment as a question, a request, or a nit, says what can wait, and keeps praise separate. review-pr verifies the change; this skill decides what to say to the author, and runs review-pr after its own reading when it is installed. Reads the reviewer's own past comments from .claude/review-feedback/examples.md when that file exists. Use whenever the user wants comments they can post, feedback for the author of a PR, "what would I say about this PR", or a review in their own voice; also after review-pr when the user asks for comments rather than a report. Code pull requests only.
license: MIT
---

# Review feedback

`review-pr` answers whether a change is correct: it verifies facts, weighs evidence, and prints a report. This skill answers a different question: what would the reviewer say to the author. The two are kept apart because they pull in opposite directions. Verification wants few, well-founded findings with a fix attached. Feedback wants every question the reviewer would actually ask, including the ones whose answer only the author has, phrased so the author can act on them and so the reviewer can post them as they are.

The reviewer's stance, in one paragraph: the author is asking for a decision and, whether they know it or not, for what to learn. The reviewer's job is to return the burden of proof to where it belongs. A description, an ADR, or a comment in the code is a claim, not a fact; the diff is the fact. When placement, a name, or a sentence cannot be understood without the author's explanation, the comment asks for the explanation rather than supplying one. Preferences are labelled as preferences, and what can wait is said to be able to wait, so the author knows what the reviewer is actually asking for.

## Target

A code pull request only: a PR number or URL, a branch, a commit range, or the current branch against its base, resolved as `review-pr` resolves them. Documents, proposals, and designs without code are out of scope; say so and stop.

## Step 1: Read the change before the description

Read the diff and the code around it first, and do not open the PR body yet. Once the author's framing is in view, everything gets judged inside that frame; the questions worth asking are the ones that come up before it. Do not run `review-pr` yet either: verification comes in Step 3, after the list below exists, because once a verifier's findings are on the table they crowd out the questions.

Do these three things in this order, before reading any of the diff. Each is a tool call, not a note to self:

1. Read `.claude/review-feedback/examples.md` (in the project or in the home directory) when it exists, now and not after the walk; Calibration below says what to read it for.
2. Take the changed paths (`git diff --stat`, or the file list the caller prepared) and match them against `review-pr`'s routing table, `references/routing.md`. For every row that matches, call the Skill tool on every knowledge skill the row names, when it is installed (under a plugin, with that plugin's prefix). Reading the routing table is not loading the skills. Their rules are what the reviewer's most frequent requests are made of; loaded only in Step 3, they reach the verifier's report and are dropped there, and loaded now, they reach the list.
3. Open [references/by-file.md](references/by-file.md).

Then walk every changed file, as a ledger. Take the changed-paths list from item 2 and, for each path in that order, write one line before opening the next file: the path, then the candidates (`path:line`, the question or the request) or the word `nothing`. The ledger is complete only when every path in the list has its line, including every kind `by-file.md` lists: configuration and tool files, locale files, schema files, layouts, fixtures, specs and factories, generated files. A path without a line is a file that was not reviewed. `by-file.md` lists what the reviewer asks about each kind of file; a file with nothing to ask gets `nothing`, not an invented comment.

Across the change as a whole, these are the questions the reviewer asks most, in that order, in the form they ask them:

- Could this ride on something that already exists? "Couldn't this use the existing X?" is the reviewer's most frequent question: an existing action, form, helper, scope, job, or gem, before a new one. Search for the sibling that solves the same problem and name it.
- Why is it here? Which layer does the repository's own layering (its `CLAUDE.md`, rules, or the evident structure) assign this kind of decision to, and is this that layer? A controller that drives a library, a view or serializer that decides, a data-access object with a business rule, application knowledge inside a library directory.
- Why this way rather than the plain way? A hand-rolled mechanism where the framework has one, a flag where a scope would do, a new endpoint where a standard action would do, `includes` where the intent was `eager_load`, a `before_action` that hides what the action needs.
- Who knows about whom? A method, partial, component, or job that knows where it is called from, or a library-like piece that knows the application, has its dependency pointing the wrong way.
- What is this for? A file, a line, a constant, an argument, or a condition the description does not explain gets "what is this for?" even when you could guess. The point is to have the author say it, in the PR, where the next reader will look.
- Does the name say what the thing is, rather than how it was implemented or where it is used?
- Can this sentence be understood in one reading? A code comment, a commit message, or a paragraph of documentation that needs the PR to make sense gets "I don't follow this sentence", said plainly.
- What is in the diff that the change does not need: leftovers, debug output, commented-out code, unrelated files, a comment that only restates the code?

Edge cases (nil, empty, run twice, failure halfway) are `review-pr`'s job in Step 3; the walk asks only whether they have a test.

Keep the list even when a question feels obvious. Half of the comments the reviewer posts are questions, and most of them are "why", not "what if".

## Step 2: Then read the author's account

Now read the title, body, commit messages, linked tickets or ADRs, and the repository's rules. Go through the list from Step 1:

- Strike a question the account answers with evidence (a link, a measurement, a screenshot, a test).
- Keep a question the account answers with an assertion. Quote the assertion and ask for what would show it: the case that needs it, the number, the discussion where it was decided.
- Add what the account promises that the diff does not deliver, and what the diff does that the account does not mention. Both are questions to the author.
- Note what the PR should show and does not: how it was verified, before and after where the UI changes, the failing test for a bug fix. `review-pr`'s report lists the rest under "Missing evidence" in Step 3.

The repository's own rules outrank the reviewer's habits, as in `review-pr`. A pattern the repository has decided on is not a finding, even when the reviewer would have chosen otherwise; the question then is whether this change follows the decision.

## Step 3: Verify

Now, with the candidate list written, run `review-pr` on the same target if it is installed, handing it what Steps 1 and 2 already gathered (the changed paths, the loaded knowledge skills, the rules, the author's account) so it does not read them again; if the caller already handed you its report, use that. Its verdict decides whether the change is approved; Step 5 decides how that is said. Every Must from its findings becomes a request, in this skill's voice and as short as the other comments; of the rest, take at most two into the comments, and the others go under "For later" in one line each, or are dropped. A Should, a Nit, or a Question from the report is posted only when it is also a point the reviewer raises (Step 4). Do not re-derive what it verified, and do not let its report reorder Step 1: the questions are the review, the findings are its footnotes.

Without `review-pr`, check the candidates from Step 1 that are about correctness yourself before posting them as facts, and post the rest as questions.

## Step 4: Decide what to say

Go through the remaining list. The default is to post. A candidate is dropped only for a reason under "Let pass" below, never because it is a preference, a house rule, minor, or small next to a bigger point: a preference is posted as a `nit` that says it is one, and "low value" is not a reason the reviewer uses. In the order they raise things most often:

1. Placement and the direction of dependencies: Step 1's "Why is it here?" and "Who knows about whom?".
2. The framework's own mechanism over a hand-rolled one; the knowledge skills loaded in Step 1 hold the specifics.
3. Names: does each say what the thing is. A name that leaks the implementation (`upsert`, `to_i`) or the call site (`for_admin`, `is_top_page`) gets a question.
4. The data model as a record of facts: constraints, comments on tables and columns, history kept rather than overwritten, meaning not hung on timestamps the framework maintains.
5. Tests as a specification: random factory values, results rather than implementation, the edge cases from Step 1.
6. Prose: a comment that translates its method name, a sentence that needs the PR to be understood, a summary buried below the detail.
7. Hygiene: unrelated diffs, leftovers, a PR too small to show its purpose or too large to judge, verification not shown, a discussion the PR does not link to.
8. Operations: what is logged versus alerted, secrets in source, cache keys, cost.

Let pass:

- Formatting and mechanical lint, whether or not a tool is configured; the Output tests name them.
- Anything the repository has decided in writing: its `CLAUDE.md`, its rules, its linter configuration. A neighbour that does the same thing is not a decision. A `before_action` that sets a variable, `includes` where a join was meant, a method extracted for a line-count cop, a branch where a 404 belongs: ask about them even when every sibling has them, because the reviewer asks there too. A naming or layout convention the codebase follows throughout is different; at most say what you would do differently and mark it a preference.
- Problems outside the diff that the change does not make worse. At most one line under "For later".
- Praise. It goes in its own place, never inside a comment that asks for something.

How many: every candidate that survives "Let pass", the small one posted next to the design question, not instead of it. When the same point recurs, one comment names every place. Do not go looking outside the diff for more: an index that was already missing, a test that was already absent, a pattern the codebase already had, is not this PR's comment.

## Step 5: Write the comments

Write each comment as it will be posted, following [references/comment-format.md](references/comment-format.md) for the kinds, the length, and the anchoring. Do not narrate what the code does before making the point, do not cite other files to justify one sentence, and do not explain to the author how their own code works: they wrote it. Match the length of the comments read from the examples file in Step 1. State uncertainty in a phrase ("I may be wrong about this") rather than by softening the question away.

Write in the language the repository uses for review comments. When `writing-conventions` is installed and not yet loaded, load it before writing: its `references/writing-style.md` has the review-comment register (question shapes, how to mark a preference and what can wait).

The verdict follows `review-pr`: approve, approve with requests, or request changes. The default when nothing is broken is to approve and leave the requests as homework, saying which are to be done before merge and which can follow. Request changes only for a reason the author can act on: a Must from `review-pr`, a rule the repository itself states was broken, data can become inconsistent, the PR does not show how it was verified, unrelated changes are mixed in, the PR is sliced so finely its purpose cannot be judged, or the branch was force-pushed during review without the reviewer's agreement.

## Calibration from past comments

The examples file holds comments the reviewer posted before, with the code they pointed at. Read it for which files and lines they stop at, what they raise and what they let pass, how much they write, and how they phrase a question, a request, and a preference. Do not copy sentences from it, and do not treat it as rules: the repository's own decisions still outrank it, and a habit that the current codebase has settled differently is not a finding.

## Output

Print the comments in the format of [references/comment-format.md](references/comment-format.md). Before printing, run every comment through these four tests and fix what fails; they catch what the author would otherwise have to untangle:

1. One point. A comment that says "also", "same for", "while here", or whose second sentence is about a different line, identifier, or file, is two comments. Split it into two entries; never drop one to make the other fit. One comment may name several places only when it is the same point at each.
2. A question ends at its question mark. Delete the sentence that follows it, or make the comment a request. "Which case is this for? As it stands X cannot happen." is a question with an answer appended; keep the question.
3. Nothing a linter or formatter reports. Trailing whitespace, a blank line at the end of a file, indentation, an unused variable or assignment, a missing trailing comma: delete the comment. The reviewer never posts these, however the change looks.
4. No narration. A comment that walks through what the code does before or after its point carries narration; cut it, keep the point and its reason.

Then read what is left once more as the author will: each comment should be answerable or actionable in a reply, and none should need the reviewer to have read the code aloud first. When the caller asks for structured output, map the sections as [references/structured-output.md](references/structured-output.md) describes; the same file is used by tools that turn the comments into review threads.
