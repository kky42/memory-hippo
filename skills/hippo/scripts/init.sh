#!/bin/sh
# Create the memory store. Safe to rerun: never overwrites existing files.
set -eu
dir=${HIPPO_DIR:-$HOME/.hippo}
here=$(cd "$(dirname "$0")" && pwd)

if [ -d "$dir" ] && [ ! -f "$dir/MEMORY.md" ] && [ -n "$(ls -A "$dir")" ]; then
  echo "$dir exists and is not a hippo store; move it away first" >&2
  exit 1
fi
mkdir -p "$dir/topics" "$dir/daily"
cd "$dir"

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
