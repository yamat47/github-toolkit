#!/usr/bin/env bash
# Vendor (or refresh) a skill directory from another GitHub repository.
#
# Usage: tools/vendor-skill.sh OWNER/REPO PATH/IN/REPO REF [DEST]
#   e.g. tools/vendor-skill.sh anthropics/skills skills/skill-creator main
#
# Downloads the repository tarball at REF with `gh`, replaces DEST
# (default: skills/<basename of PATH>) with the upstream directory, and prints
# the resolved commit SHA so it can be recorded in README.md.
set -euo pipefail

if [ $# -lt 3 ]; then
  sed -n '2,8p' "$0"
  exit 1
fi

repo="$1"; path="$2"; ref="$3"; dest="${4:-skills/$(basename "$path")}"
sha="$(gh api "repos/${repo}/commits/${ref}" --jq '.sha')"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

gh api "repos/${repo}/tarball/${sha}" > "$tmp/src.tgz"
tar xzf "$tmp/src.tgz" -C "$tmp"
src="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d)/${path}"
[ -d "$src" ] || { echo "error: ${path} not found in ${repo}@${ref}" >&2; exit 1; }

rm -rf "$dest"
mkdir -p "$(dirname "$dest")"
cp -R "$src" "$dest"

echo "vendored ${repo}/${path}@${sha} -> ${dest}"
echo "remember to re-apply local frontmatter tweaks (e.g. license:) and update README.md"
