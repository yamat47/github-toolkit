# Showing the change in the pull request

Used by Step 4 and Step 8 of the create-pr skill when the change is something a person sees.

## 1. Look at it running

A change to a page, a screen, a component or a command's output is verified by looking at it, not only by the checks. Run the project the way it documents (a `run` skill, `.claude/launch.json`, the README) and open the change in the browser pane at the width the project targets (a phone width for a mobile-first app). Go through each state the change adds or alters: empty, filled, saving, failed, the second theme when the project has one, the screen it pushes and the way back.

Take a screenshot of each state that a reviewer would otherwise have to reproduce. The browser tool saves every screenshot as a file and prints its path; keep the path with a one-line caption that says what the picture shows, in the project's words ("The Weight tab in the last month, with the goal line"). Two to six pictures is the usual count; one per state, none for a state the diff makes obvious.

A change nothing shows (a Worker route, a migration, a script, docs) has no pictures. Say so in Step 8 only if the PR template asks for them.

## 2. Keep the pictures where GitHub can show them

GitHub shows an image in a pull request body only from a URL it can fetch. A local path shows nothing, and `gh` cannot attach a file the way the web form does. So the pictures go into the repository itself, on one branch that holds nothing else and that nobody merges: `pr-images`. The branch is history the repository's default branch never carries.

Work in a separate worktree so the checkout and its index stay as they are:

```bash
git fetch origin pr-images
```

If the fetch found the branch:

```bash
git worktree add --detach .tmp/pr-images origin/pr-images
```

If it did not (the first pull request with pictures in this repository):

```bash
git worktree add --orphan -b pr-images .tmp/pr-images
```

Copy the screenshots into a folder named after the branch, with short names that say what they show:

```bash
mkdir -p .tmp/pr-images/<branch>
```

```bash
cp <saved screenshot> .tmp/pr-images/<branch>/weight-month.png
```

Commit and push from inside the worktree (one commit, a plain subject; the message needs no Why):

```bash
git -C .tmp/pr-images add <branch>
```

```bash
git -C .tmp/pr-images commit -m "Screenshots for <branch>"
```

```bash
git -C .tmp/pr-images push origin HEAD:pr-images
```

Note the commit:

```bash
git -C .tmp/pr-images rev-parse HEAD
```

Then remove the worktree; the branch stays on the remote:

```bash
git worktree remove .tmp/pr-images
```

The URL of a picture is pinned to that commit, so later pushes to `pr-images` never move it:

```
https://github.com/<owner>/<repo>/blob/<commit>/<branch>/weight-month.png?raw=true
```

GitHub serves it to anyone who can read the repository, so it works for a private repository too. A screenshot that is a JPEG keeps its `.jpg` name.

## 3. Put them in the body

Phone screenshots are tall, so write them as `<img>` with a width and the caption as `alt`, several on one line so they sit side by side:

```markdown
<img src="https://github.com/<owner>/<repo>/blob/<commit>/<branch>/weight-month.png?raw=true" width="280" alt="The Weight tab in the last month, with the goal line"> <img src="…/weight-week.png?raw=true" width="280" alt="The same week, the period switched to W">
```

Each caption says what the reviewer is looking at and what to notice, in one sentence; the pictures are the evidence the "what was verified" sentence of the body points at, not decoration. A desktop screenshot takes the plain `![caption](url)` form at its own width.

If the repository has a convention of its own for where pull request images live (a `docs/screenshots/` folder it keeps on purpose, an issue that hosts them), follow it instead of the `pr-images` branch.

## 4. When the branch gets heavy

`pr-images` only grows. When it weighs on a clone, the owner deletes the folders of merged pull requests whose pictures no longer matter and force-pushes the branch; the pinned URLs in those old pull requests stop showing, which is the accepted cost. Never force-push it for any other reason.
