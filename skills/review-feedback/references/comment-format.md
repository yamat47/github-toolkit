# Comment format

The output is Markdown printed to the terminal. The four headings below always appear, in this order, spelled exactly like this, so other tools can split it. A section with nothing to say contains the single line `None.`

```markdown
# Review comments: <PR title or branch> (<target as given>)

## Verdict

<Approve | Approve with requests | Request changes>. <One sentence: what decided it. When requesting changes, the reason from the list in SKILL.md.>
<When approving with requests: which comments are to be done before merge, and which can follow.>

## Comments

### `path/to/file.rb:12` question

<The comment as it will be posted.>

### `path/to/file.rb` request

<The comment as it will be posted. A request says in one line why.>

### `path/to/file.rb:40` nit, deferrable

<The comment as it will be posted.>

## Aside

- <Praise or an observation, one line each. Never inside a comment that asks for something.>

## For later

- <Something outside this PR worth recording, one line each, with where to record it if known.>
```

## Kinds

| Kind | Use when | The author may |
| --- | --- | --- |
| `question` | The answer is the author's: why here, why this way, what case needs it, was this considered. Also a correctness concern you cannot confirm; say what you are unsure of. | Answer, and the answer may close the thread |
| `request` | The change should be made and the reviewer can say why in one line. Verified findings from `review-pr` are requests. | Do it, or explain why not |
| `nit` | A preference, a wording, a habit. | Ignore it |

Any kind can carry `deferrable`: fine in a follow-up PR. Say so in the heading, and say it again in the text when the author might not read headings.

## The text

- The first line is the point. What follows is the reason or the case, in one to three more lines; the whole comment is two to four lines as posted, under forty words unless a `suggestion` block carries the code. A comment longer than that is usually two comments, or narration of the code that the author does not need.
- One point per comment. When the same point holds in several places, one comment names every place.
- A question ends with the question. Do not wrap it in paragraphs of hedging; state uncertainty once, in a phrase.
- A request names the alternative. When replacement code is clearer than prose, use a `suggestion` block for exactly the lines it replaces.
- No praise inside a comment. Praise is a line under Aside.
- Code identifiers, paths, and quoted strings stay as they are in the code.
- Prose rules and the Japanese register are in `writing-conventions` (`references/writing-style.md`, review comments).

## Anchoring

- A comment about a line or a range is anchored to that line or range in the new version of the file.
- A comment about a file as a whole, or about the design of the change, is anchored to the file, with no line. A design question goes on the file it concerns most; do not spread one question over several files.
- A comment about the PR itself (its size, what it mixes, what it does not show) goes under Verdict, not under Comments.
