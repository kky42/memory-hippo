#!/bin/sh
# Check memory budgets and formats. Prints each problem; exit 1 if any.
set -eu
export LC_ALL=en_US.UTF-8
cd "${HIPPO_DIR:-$HOME/.hippo}"
bad=0
say() { echo "$1"; bad=1; }
chars() { wc -m < "$1" | tr -d ' '; }

if [ -f MEMORY.md ]; then
  n=$(chars MEMORY.md)
  [ "$n" -le 4000 ] || say "MEMORY.md: $n chars, over 4000; compress or move detail to topics"
else
  say "MEMORY.md: missing"
fi

count=0
for f in topics/*; do
  [ -e "$f" ] || continue
  b=${f#topics/}
  [ "$b" = .gitkeep ] && continue
  if ! echo "$b" | grep -Eq '^[a-z0-9][a-z0-9-]*\.md$'; then
    say "$f: name must be lowercase-kebab .md"; continue
  fi
  count=$((count + 1))
  n=$(chars "$f")
  [ "$n" -le 8000 ] || say "$f: $n chars, over 8000; compress, merge, or drop least important"
  sed -n 1p "$f" | grep -q '^# ' || say "$f: line 1 must be '# <name>'"
  sed -n 2p "$f" | grep -Eq '^[^-#[:space:]]' || say "$f: line 2 must be a one-line scope"
done
[ "$count" -le 20 ] || say "topics: $count files, over 20; merge topics"

if [ ! -f TOPIC_INDEX.md ]; then
  say "TOPIC_INDEX.md: missing; run update_topic_index.sh"
else
  for f in topics/*.md; do
    [ -e "$f" ] || continue
    grep -qFx -- "- $f: $(sed -n 2p "$f")" TOPIC_INDEX.md || say "$f: missing or stale in TOPIC_INDEX.md; run update_topic_index.sh"
  done
  for f in $(sed -n 's/^- \(topics\/[a-z0-9-]*\.md\):.*/\1/p' TOPIC_INDEX.md); do
    [ -e "$f" ] || say "$f: indexed but does not exist; run update_topic_index.sh"
  done
fi

set -- MEMORY.md
for f in topics/*.md; do [ -e "$f" ] && set -- "$@" "$f"; done
if grep -in '(as of' "$@" 2>/dev/null; then
  say '"(as of" stamps in the lines above; a date belongs only inside a fact, like a deadline'
fi

if grep -lE '^(<<<<<<<|>>>>>>>)' "$@" 2>/dev/null; then
  say "conflict markers in the files above"
fi

[ "$bad" -eq 0 ] && echo ok
exit "$bad"
