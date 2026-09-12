# Frozen fixture: stale installed skills

This directory is what `gh skill install yamat47/github-toolkit skill-creator@v1.0.0 --dir tests/fixtures/installed-skills` produced. CI runs the `update-skills` reusable workflow against it in dry-run mode and asserts that `gh skill update` reports an available update, which is only true while the installed copy is older than the latest release of this repository.

Never update it, never re-run `gh skill update` on it, and never bump `github-ref` or `github-tree-sha` in its `SKILL.md`. The stale content is the test.
