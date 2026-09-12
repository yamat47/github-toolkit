# Prose style

Applies to code comments, commit messages, pull requests, issues, review comments, and documents under `docs/`. What belongs in each of those is in [what-goes-where.md](what-goes-where.md). Rules marked **(Japanese)** apply only when writing Japanese.

## Basics

- Plain declarative register, active voice, present tense. **(Japanese)** である調.
- One idea per sentence. Do not keep chaining clauses with commas.
- Bold is for the name of a concept and for a conclusion. Do not use it several times in one paragraph.
- No em dashes. End the sentence, or use parentheses. **(Japanese)** Use half-width parentheses `(` `)`.
- No emoji, no arrows (→), and no bullets of the form "**Label**: explanation".
- Do not repeat the same metaphor or catchphrase.

## Expressions not to use

Avoid the phrasing that marks generated text.

- Declarations of benefit: "enables", "makes it possible", "improves", "ensures", "robust", "keeps consistency", "seamless", "efficiently", "appropriately". Write what changes, as fact. Do not write the benefit.
- **(Japanese)** Calques from English: 保証する (ensure), 処理する (handle), 活用する (leverage), サポートする, 対応する, 〜という点が重要, 〜の表れである, 〜側に落ちる. Replace them with a concrete Japanese verb.
- Meta statements: "to summarize", "the key point is", "notably", "the following changes were made", "first / next / finally". Start with the substance.
- Unfounded hedging: "it seems", "may", "just in case". If you verified it, state it. If you did not, say you did not.
- Narrating the diff: lists of changed files, sentences that only string together class and method names. Do not write what can be read from the diff.
- Filling blanks: "N/A", "none". Delete a section that has nothing to say.

## Structure

- Three sentences or fewer go in prose. Headings and bullets are not the default.
- Do not add headings like "Overview", "Main changes", or "Summary" mechanically.
- Bullets are for parallel items only. A line of argument stays in prose.
- Never leave a section or item as "(empty)". Delete sections that cannot be filled.

## Documents under docs/

Match the existing documents in the repository. The rules above are extracted from them; when in doubt, read the originals.
