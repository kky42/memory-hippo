#!/bin/sh
# Install the latest hippo skill with npx skills, then run the new init_hippo.sh.
# Prints the skill diff, so the agent knows whether to re-read SKILL.md and bring ~/.hippo
# in line with it. Never edits memory itself. Idempotent.
set -eu
src=${HIPPO_SOURCE:-kky42/memory-hippo}
skill=$(cd "$(dirname "$0")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cp -R "$skill" "$tmp/old"
npx -y skills add "$src" -g -y -a claude-code -a codex -a pi
if diff -ru "$tmp/old" "$skill"; then
  echo "skill unchanged: already the latest"
else
  echo "skill updated (diff above): re-read SKILL.md and bring ~/.hippo in line with it"
fi
"$skill/scripts/init_hippo.sh"
