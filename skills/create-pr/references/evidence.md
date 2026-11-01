# Showing the change in the pull request

Used by Step 4 and Step 8 of the create-pr skill when the change is something a person sees.

## 1. Look at it running

A change to a page, a screen, a component or a command's output is verified by looking at it, not only by the checks. Run the project the way it documents (a `run` skill, `.claude/launch.json`, the README) and open the change in the browser pane at the width the project targets (a phone width for a mobile-first app). Go through each state the change adds or alters: empty, filled, saving, failed, the second theme when the project has one, the screen it pushes and the way back.

Take a screenshot of each state that a reviewer would otherwise have to reproduce. The browser tool saves every screenshot as a file and prints its path; keep the path with a one-line caption that says what the picture shows, in the project's words ("The Weight tab in the last month, with the goal line"). Two to six pictures is the usual count; one per state, none for a state the diff makes obvious.

A change nothing shows (a Worker route, a migration, a script, docs) has no pictures. Say so in Step 8 only if the PR template asks for them.

## 2. Attach them with gh

`gh` 2.99.0 and later upload a local image or video with the repeatable `--attach` flag on `gh pr create`, `gh pr edit` and `gh pr comment` (and `gh issue create`); the file goes to GitHub's own attachment store, as a drop into the web form would. Nothing is committed anywhere. Uploading needs push access to the repository; up to 50 files go in one command.

Write the body with the pictures as ordinary Markdown images, each with its caption as the alt text and the file by a path relative to the body file's directory:

```markdown
## What it looks like

![The Weight tab in the last month, with the goal line](./weight-month.png)
![The same week, the period switched to W](./weight-week.png)
```

Keep the screenshots beside the body file, named for what they show, and pass each one with `--attach`; a reference in the body to an attached file is rewritten to the uploaded asset, and an attached file the body does not mention is appended at the end:

```bash
gh pr create --draft --base main --head "<BRANCH>" --title "<title>" --body-file .tmp/pr/body.md --attach .tmp/pr/weight-month.png --attach .tmp/pr/weight-week.png
```

For an existing pull request, `gh pr edit <number>` takes the same flags. Alt text can also follow the path after `#` (`--attach './weight-month.png#The Weight tab in the last month'`) when the body does not reference the file; a Markdown reference in the body keeps the alt text written there. A video renders as a player and has no alt text.

A `gh` without `--attach` is older than 2.99.0: upgrade it. Until then the pictures cannot go into the body from the command line, and the body says what was looked at in words.

Each caption says what the reviewer is looking at and what to notice, in one sentence; the pictures are the evidence the "what was verified" sentence of the body points at, not decoration.
