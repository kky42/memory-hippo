#!/bin/sh
# Create the memory store, then inject the block into each FILE given. Safe to rerun:
# never overwrites store files; replaces only the <memory-hippo> block in FILEs.
set -eu
dir=${HIPPO_DIR:-$HOME/.hippo}
here=$(cd "$(dirname "$0")" && pwd)

if [ -d "$dir" ] && [ ! -f "$dir/MEMORY.md" ] && [ -n "$(ls -A "$dir")" ]; then
  echo "$dir exists and is not a hippo store; move it away first" >&2
  exit 1
fi
mkdir -p "$dir/topics"
cd "$dir"

# older stores kept notes in daily/YYYY-MM-DD.md; queue them, oldest first, into PENDING.md
if [ -d daily ]; then
  for f in daily/*.md; do
    if [ -e "$f" ]; then cat "$f" >> PENDING.md; rm "$f"; fi
  done
  rmdir daily 2>/dev/null || echo "daily/ still has non-note files; left in place" >&2
fi

[ -f MEMORY.md ] || : > MEMORY.md
[ -f topics/.gitkeep ] || : > topics/.gitkeep
seed() {
  [ -f "topics/$1.md" ] || printf '# %s\n%s\n' "$1" "$2" > "topics/$1.md"
}
seed user "Who the user is: role, background, expertise, goals."
seed feedback "How the user wants agents to work: corrections, preferences, rules."
seed project "Ongoing work: projects, decisions, deadlines, status."
seed reference "Where things live: repos, machines, services, URLs, docs."

[ -f .gitignore ] || printf '%s\n' '/*' '!/.gitignore' '!/MEMORY.md' \
  '!/TOPIC_INDEX.md' '!/topics/' > .gitignore
"$here/update_topic_index.sh"

if [ ! -d .git ]; then
  git init -q
  git add .gitignore MEMORY.md TOPIC_INDEX.md topics
  git commit -qm "init"
fi
echo "hippo store ready at $dir"

# Inject block.md into each agent instruction file given as an argument:
# replace an existing <memory-hippo> block, or append one at the end.
block="$here/../block.md"
for f in "$@"; do
  mkdir -p "$(dirname "$f")"
  [ -f "$f" ] || : > "$f"
  opens=$(grep -c '^<memory-hippo>$' "$f" || true)
  closes=$(grep -c '^</memory-hippo>$' "$f" || true)
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
      /^<memory-hippo>$/ { while ((getline l < blk) > 0) print l; skip = 1; next }
      skip { if ($0 == "</memory-hippo>") skip = 0; next }
      { print }' "$f" > "$tmp"
  else
    rm -f "$tmp"
    echo "$f: malformed <memory-hippo> block; fix it by hand" >&2
    exit 1
  fi
  if cmp -s "$tmp" "$f"; then
    echo "$f: block up to date"
  else
    cat "$tmp" > "$f"
    echo "$f: block written"
  fi
  rm -f "$tmp"
done
