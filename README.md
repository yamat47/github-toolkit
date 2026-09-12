# github-toolkit

[![CI](https://github.com/yamat47/github-toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/yamat47/github-toolkit/actions/workflows/ci.yml)

A monorepo that distributes [Agent Skills](https://agentskills.io/specification) for Claude Code and other agents, together with GitHub Actions (composite actions and reusable workflows). One git tag versions everything.

## Usage

### Install a skill

```sh
gh skill install yamat47/github-toolkit <skill-name>
```

Skills are discovered automatically from `skills/<skill-name>/SKILL.md`. Without a version, `gh` installs the latest GitHub release; add `@v1.2.0` or `--pin v1.2.0` to pin a tag, or `--pin main` to follow the branch head. Use `--agent claude-code --scope user` to install for Claude Code globally.

This repository is intentionally not listed in the public skill catalog (`gh skill search`); it is meant for people who already know it exists.

### Use an action

```yaml
- uses: yamat47/github-toolkit/actions/<action-name>@v1.0.0
```

### Use a reusable workflow

```yaml
jobs:
  example:
    uses: yamat47/github-toolkit/.github/workflows/<workflow-name>.yml@v1.0.0
```

`@v1.0.0` pins an exact release; there are no floating tags such as `@v1`. `@main` follows the branch head for anyone who prefers to always get the latest. Dependabot in a consuming repository bumps exact pins to new releases automatically.

## Contents

### Skills

| Skill | Description | Upstream |
|---|---|---|
| [`skill-creator`](skills/skill-creator) | Create, improve, evaluate, and benchmark Agent Skills. | Vendored from [anthropics/skills](https://github.com/anthropics/skills/tree/main/skills/skill-creator) at `34040c9`, Apache-2.0 (see its `LICENSE.txt`). |
| [`gh-stack`](skills/gh-stack) | Manage stacked branches and pull requests with the `gh stack` CLI extension. | Vendored from [github/gh-stack](https://github.com/github/gh-stack/tree/main/skills/gh-stack) at `2bd699a` (v0.1.1), MIT. |
| [`grill-me`](skills/grill-me) | Interview the user about a plan or design one question at a time, in dependency order, before implementing. | Own, MIT. |
| [`create-pr`](skills/create-pr) | From uncommitted changes to a draft pull request in one run: detect and run checks, fix failures, split into Conventional Commits, push, open the PR. Also covers commits-only runs. | Own, MIT. Reads `writing-conventions` when installed. |
| [`writing-conventions`](skills/writing-conventions) | House style for code comments, test names, commit messages, pull requests, and docs (what goes where, and prose rules). Background knowledge for other skills. | Own, MIT. |
| [`dhh-rails-patterns`](skills/dhh-rails-patterns) | DHH / 37signals style Rails implementation patterns, consulted as background knowledge while writing Rails code. | Own, MIT. |

```sh
gh skill install yamat47/github-toolkit create-pr
gh skill install yamat47/github-toolkit writing-conventions
```

`skill-creator` and `gh-stack` are unmodified upstream copies except for the `license:` frontmatter line, kept here so one `gh skill install` source covers everything. Skills that take a Claude Code-only frontmatter key such as `user-invocable` do not carry it, because the Agent Skills validator rejects unknown keys; their descriptions say when they are background knowledge instead.

### Actions

Thin wrappers pin one upstream action to a full commit SHA and mirror its inputs and outputs, so they are drop-in replacements. Recipes chain several steps that always appear together.

| Action | Wraps | Notes |
|---|---|---|
| [`actions/checkout`](actions/checkout) | [actions/checkout](https://github.com/actions/checkout) | Same inputs and outputs as upstream. |
| [`actions/setup-ruby`](actions/setup-ruby) | [ruby/setup-ruby](https://github.com/ruby/setup-ruby) | Same inputs and outputs as upstream. |
| [`actions/setup-node`](actions/setup-node) | [actions/setup-node](https://github.com/actions/setup-node) | Same inputs and outputs as upstream. |
| [`actions/setup-pnpm`](actions/setup-pnpm) | [pnpm/action-setup](https://github.com/pnpm/action-setup) | Same inputs and outputs as upstream. |
| [`actions/cache`](actions/cache) | [actions/cache](https://github.com/actions/cache) | Same inputs and outputs as upstream, minus the deprecated `save-always`. |
| [`actions/upload-artifact`](actions/upload-artifact) | [actions/upload-artifact](https://github.com/actions/upload-artifact) | Same inputs and outputs as upstream. |
| [`actions/setup-node-with-pnpm`](actions/setup-node-with-pnpm) | pnpm/action-setup + actions/setup-node + `pnpm install` | Recipe. pnpm version from `packageManager`, pnpm store cached, `--frozen-lockfile` by default. |
| [`actions/setup-playwright-chromium`](actions/setup-playwright-chromium) | actions/cache + `playwright install` | Recipe. Installs Chromium for the Playwright version the project depends on; browser download cached per version. |
| [`actions/undercover`](actions/undercover) | [undercover](https://github.com/grodowski/undercover) + `gh` | Recipe. Runs diff coverage after the tests, annotates untested lines, keeps one sticky PR comment. Never fails the job; read the `status` output. |

Dependabot bumps every pin to each new upstream release.

```yaml
- uses: yamat47/github-toolkit/actions/checkout@v1.0.0
  with:
    fetch-depth: 0

- uses: yamat47/github-toolkit/actions/setup-ruby@v1.0.0
  with:
    working-directory: application
    bundler-cache: true

- uses: yamat47/github-toolkit/actions/setup-node-with-pnpm@v1.0.0
  with:
    node-version: 24
    package-json-file: application/package.json
    cache-dependency-path: application/pnpm-lock.yaml
    working-directory: application

- uses: yamat47/github-toolkit/actions/setup-playwright-chromium@v1.0.0
  with:
    working-directory: application

- uses: yamat47/github-toolkit/actions/undercover@v1.0.0
  if: github.event_name == 'pull_request'
  with:
    working-directory: application
```

`undercover` needs `fetch-depth: 0` on the checkout and `pull-requests: write` on the job. The comment text is English by default; override `warnings-title`, `warnings-body`, `error-title`, and `error-body` for another language.

### Reusable workflows

(none yet)

## Layout

```
skills/<name>/SKILL.md      # Skill (optionally with scripts/ references/ assets/)
actions/<name>/action.yml   # Composite or JavaScript action (wrapper or recipe)
tests/fixtures/             # Sample projects and recorded logs used by CI to exercise the actions
.github/workflows/          # Reusable workflows (workflow_call) and this repo's own CI
.github/dependabot.yml      # Keeps SHA-pinned action references current
docker/                     # Dockerfile for local tooling
compose.yaml, Makefile      # Local tooling entrypoints (everything runs in Docker)
tools/                      # Maintenance scripts for this repo (not distributed)
```

## Development

All local checks run in Docker; only Docker itself needs to be installed. CI runs the same targets.

```sh
make lint            # run every check
make lint-workflows  # actionlint on .github/workflows/*.yml
make lint-actions    # schema validation of actions/*/action.yml
make lint-skills     # validate skills/*/SKILL.md against the Agent Skills spec
```

`gh skill publish --dry-run` runs the official `gh` validator using your login; CI runs it too. Never run it without `--dry-run`: the real command adds the `agent-skills` topic, which lists the repository in the public skill catalog.

### Adding a skill

1. Create `skills/<name>/SKILL.md`. The frontmatter must contain `name` (equal to the directory name; lowercase letters, digits, and single hyphens, max 64 chars) and `description` (max 1024 chars). Add `license:` as well; `gh skill publish` warns when it is missing.
2. Write the `description` to cover both what the skill does and when to use it, including the keywords a user would say. Agents decide whether to load a skill from this field alone.
3. Keep `SKILL.md` under 500 lines. Put long material in `references/`, executable helpers in `scripts/`, and templates in `assets/`, linked by relative path from `SKILL.md`.
4. Run `make lint-skills` and `gh skill publish --dry-run`.
5. Add a row to the Skills table above, then cut a release (see below).

To vendor a skill from another repository instead, run `tools/vendor-skill.sh OWNER/REPO PATH REF`, keep its license file, add `license:` to the frontmatter if upstream lacks it, and record the upstream commit in the Skills table. Re-run the script with a newer ref to refresh.

### Adding an action

1. Create `actions/<name>/action.yml` with `name`, `description`, `inputs`, `outputs`, and `runs` (`using: composite`, or `node24` for a JavaScript action). Every composite step needs `shell:`.
2. When wrapping an upstream action, pin it to a full commit SHA followed by a version comment, e.g. `uses: actions/checkout@<sha> # v7.0.1`. Dependabot reads the comment and bumps both.
3. Mirror upstream inputs and outputs by name so the wrapper is a drop-in replacement. Composite inputs are strings; quote defaults such as `"true"`.
4. Add an end-to-end job to `.github/workflows/ci.yml` that runs the action with `uses: ./actions/<name>`. actionlint then also checks that every input the job passes exists. Put any sample project or recorded output the job needs under `tests/fixtures/`.
5. A recipe that chains other actions pins the upstream actions directly rather than using `./actions/<name>`: a relative `uses:` inside a composite action resolves against the caller's workspace, and an exact-tag self-reference cannot exist before the tag does.
6. Run `make lint`, add a row to the Actions table above, then cut a release.

### Adding a reusable workflow

1. Create `.github/workflows/<name>.yml` with `on: workflow_call` and declare `inputs`, `secrets`, and `outputs` there. Files must sit directly in `.github/workflows/`; subdirectories are not supported.
2. Callers reference it from a job, not a step: `uses: yamat47/github-toolkit/.github/workflows/<name>.yml@v1.0.0`.
3. Pin any actions it uses to full commit SHAs. Dependabot already watches this directory.
4. Run `make lint-workflows`, add a row to the Reusable workflows table above, then cut a release.

### Versioning and tags

Skills, actions, and workflows share one version line and are released together.

- Versions are semantic version git tags with a matching GitHub release: `v1.0.0`, `v1.1.0`, `v1.1.1`. The release is what `gh skill install` resolves by default and is the audit trail of what shipped when; actions and workflows resolve the tag itself.
- **Exact tags only. There is deliberately no floating `v1` or `v1.0` tag.** Tags are immutable evidence of a release, so nothing is ever force-moved. Consumers pin `@vX.Y.Z` and let Dependabot bump it, or use `@main` to follow the tip. Bump the major for a breaking change to any skill, action, or workflow.
- Releases are created with `gh release create`, never with `gh skill publish`. The latter also adds the `agent-skills` topic, which lists this repository in the public skill catalog.

To release version `X.Y.Z` from `main`:

```sh
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin vX.Y.Z
gh release create vX.Y.Z --generate-notes
```

Consider a tag protection ruleset on the repository (pattern `v*`) so released tags can never be rewritten or deleted.

## License

[MIT](LICENSE). Vendored skills keep their own license files; see the Skills table.
