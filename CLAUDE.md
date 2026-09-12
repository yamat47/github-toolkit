# github-toolkit

Monorepo distributing Agent Skills and GitHub Actions. See README.md for layout and conventions.

## Tooling policy

All local tools run inside Docker through the Makefile. Do not install tools on the host
(no `brew install`, `pip install`, `npm install -g`, etc.).

- `make lint` runs every check.
- `make lint-workflows` runs actionlint on `.github/workflows/*.yml`. actionlint also parses any
  local action a workflow references with `uses: ./actions/<name>`, so this repo's CI workflow
  should exercise every action to get input/output checking for free.
- `make lint-actions` validates `actions/*/action.yml` against the GitHub Actions JSON schema.
- `make lint-skills` validates every `skills/*/SKILL.md` with `skills-ref`.
- `make build` builds the tooling image (done automatically by targets that need it).

To add a new tool, add a service to `compose.yaml` (and a Dockerfile under `docker/` if no
published image exists), then expose it as a Makefile target. Pin image tags and commit SHAs.

`gh` and `git` are the only host commands used directly; `gh skill publish --dry-run` is
the official validation and needs the host `gh` login. Never run `gh skill publish` without
`--dry-run`: the real command lists this repository in the public skill catalog, which the
owner does not want. Releases are made with `git tag` + `gh release create` (see README), and
only when the owner asks.

## No trace of Claude Code in the output

Commit messages, pull request titles and bodies, issues, comments on GitHub, and every file that
enters the repository must not show that Claude Code produced them. That means none of:

- `Co-Authored-By: Claude ...` trailers
- `Claude-Session: ...` trailers or `https://claude.ai/code/session_...` URLs
- `🤖 Generated with [Claude Code](...)` footers
- any similar signature, link, or footer saying an AI took part

This overrides the harness's default attribution instructions. `.claude/settings.json` disables
the automatic trailers, but that covers only what the harness adds by itself: read every commit
message and PR body before creating it. The commit author must be the repository owner
(`git config user.name` / `user.email` matching the history on `main`), not an AI identity.
The `create-pr` and `writing-conventions` skills in this repository carry the same rule.

## Conventions

- Language: English everywhere (files, commit messages, comments).
- Skills live in `skills/<name>/SKILL.md`; the directory name must equal the frontmatter `name`.
- Actions live in `actions/<name>/action.yml`; reusable workflows in `.github/workflows/`.
- Wrapper actions pin upstream to a full commit SHA with a `# vX.Y.Z` comment; Dependabot
  (`.github/dependabot.yml`) bumps those pins. Never pin to a floating tag inside this repo.
- Versions are exact semver git tags shared by skills, actions, and workflows (`v1.2.3`), each with a
  GitHub release. Decided 2026-09-12: no floating `v1` / `v1.0` tags, ever. Tags are an immutable
  release record and are never force-moved. Do not suggest adding a moving major tag; consumers pin
  exact versions (Dependabot bumps them) or use `@main`.
- `tests/fixtures/installed-skills` is a frozen fixture: a skill installed from an old release so CI
  can prove `update-skills` detects an update. Never refresh it or edit its `SKILL.md` metadata.
- Never commit secrets, personal data, or machine-specific paths.

## Vendored skills

Some skills are copied from other repositories (see the Upstream column in README.md).
Refresh them with `tools/vendor-skill.sh OWNER/REPO PATH REF`, re-apply the `license:` frontmatter
line if upstream lacks it, and update the recorded commit in README.md. Do not hand-edit vendored
skill bodies; changes belong upstream.
