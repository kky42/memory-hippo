#!/bin/sh
# Make the store and agent instruction files match this skill. No arguments. Idempotent;
# never overwrites memory.
#   Creates ~/.hippo if missing, and installs or refreshes block.md in the instruction file of
#   every agent present (~/.claude, ~/.codex, ~/.pi/agent). Then runs sync_hippo.sh (topic
#   index, skill links) and, if doctor passes, commits tracked store changes.
# Exit 0 done, 1 refused or doctor failed (store changes left uncommitted).
set -eu
dir=${HIPPO_DIR:-$HOME/.hippo}
here=$(cd "$(dirname "$0")" && pwd)
block=$here/../block.md

if [ -d "$dir" ] && [ ! -d "$dir/.git" ] && [ -n "$(ls -A "$dir")" ]; then
  echo "$dir exists and is not a hippo store; move it away first" >&2
  exit 1
fi
mkdir -p "$dir/topics" "$dir/skills"
cd "$dir"
[ -d .git ] || git init -q
[ -f MEMORY.md ] || : > MEMORY.md
[ -f topics/.gitkeep ] || : > topics/.gitkeep
[ -f skills/.gitkeep ] || : > skills/.gitkeep
seed() { [ -f "topics/$1.md" ] || printf '# %s\n%s\n' "$1" "$2" > "topics/$1.md"; }
if [ -z "$(git log -1 --format=%h 2>/dev/null)" ]; then
  seed user "Who the user is: role, background, expertise, goals."
  seed feedback "How the user wants agents to work: corrections, preferences, rules."
  seed project "Ongoing work: projects, decisions, deadlines, status."
  seed reference "Where things live: repos, machines, services, URLs, docs."
fi
printf '%s\n' '/*' '!/.gitignore' '!/MEMORY.md' '!/TOPIC_INDEX.md' '!/topics/' '!/skills/' > .gitignore

set --
for f in .claude/CLAUDE.md .codex/AGENTS.md .pi/agent/AGENTS.md; do
  if [ -d "$HOME/$(dirname "$f")" ]; then set -- "$@" "$HOME/$f"; fi
done
[ $# -gt 0 ] || { echo "no agent found: expected ~/.claude, ~/.codex, or ~/.pi/agent" >&2; exit 1; }
for f in "$@"; do
  [ -f "$f" ] || : > "$f"
  opens=$(grep -c '^<hippo>$' "$f" || true)
  closes=$(grep -c '^</hippo>$' "$f" || true)
  tmp=$(mktemp)
  if [ "$opens" -eq 0 ] && [ "$closes" -eq 0 ]; then
    cat "$f" > "$tmp"
    if [ -s "$f" ]; then
      [ -z "$(tail -c 1 "$f")" ] || echo >> "$tmp"
      echo >> "$tmp"
    fi
    cat "$block" >> "$tmp"
  elif [ "$opens" -eq 1 ] && [ "$closes" -eq 1 ]; then
    awk -v blk="$block" '
      /^<hippo>$/ { while ((getline l < blk) > 0) print l; skip = 1; next }
      skip { if ($0 == "</hippo>") skip = 0; next }
      { print }' "$f" > "$tmp"
  else
    rm -f "$tmp"
    echo "$f: malformed <hippo> block; fix it by hand" >&2
    exit 1
  fi
  if cmp -s "$tmp" "$f"; then echo "$f: block up to date"
  else cat "$tmp" > "$f"; echo "$f: block written"; fi
  rm -f "$tmp"
done

"$here/sync_hippo.sh"
"$here/doctor.sh" || { echo "store not committed: fix the problems above, then rerun init_hippo.sh" >&2; exit 1; }
git add -A -- .gitignore MEMORY.md TOPIC_INDEX.md topics skills
if git diff --cached --quiet; then echo "store up to date at $dir"
else
  git diff --cached --stat
  git commit -qm "hippo: sync $(date +%F) $(hostname -s)"; echo "store committed at $dir"
fi
