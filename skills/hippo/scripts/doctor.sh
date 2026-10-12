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

if grep -nE '\(20[0-9]{2}-[0-9]{2}-[0-9]{2}\)' "$@" 2>/dev/null; then
  say 'date stamps in the lines above; a date belongs only inside a fact, like a deadline'
fi

today=$(date +%F)
for f in "$@"; do
  for d in $(grep -oE '20[0-9]{2}-[0-9]{2}-[0-9]{2}' "$f" | sort -u); do
    if [ "$d" \> "$today" ]; then echo "warn: $f: date $d is in the future; fine for a deadline, otherwise fix it"; fi
  done
done

if grep -lE '^(<<<<<<<|>>>>>>>)' "$@" 2>/dev/null; then
  say "conflict markers in the files above"
fi

# the same path or issue number in several files often means one fact kept in two places
for f in "$@"; do
  grep -oE '~/[A-Za-z0-9._/-]*[A-Za-z0-9_/-]|#[0-9]+' "$f" | sort -u | sed "s|\$|	$f|"
done | awk -F'\t' '{ n[$1]++; at[$1] = at[$1] " " $2 }
  END { for (t in n) if (n[t] > 1) print "warn: " t " appears in" at[t] }' | sort

[ "$bad" -eq 0 ] && echo ok
exit "$bad"
