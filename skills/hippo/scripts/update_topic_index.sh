#!/bin/sh
# Regenerate TOPIC_INDEX.md from line 2 (the scope line) of each topic file.
set -eu
export LC_ALL=en_US.UTF-8
cd "${HIPPO_DIR:-$HOME/.hippo}"
tmp=TOPIC_INDEX.md.tmp
{
  echo "# Topic index"
  echo
  echo "Generated from line 2 of each topic file. Do not edit."
  echo
  for f in topics/*.md; do
    [ -e "$f" ] || continue
    printf '%s\n' "- $f: $(sed -n 2p "$f")"
  done
} > "$tmp"
mv "$tmp" TOPIC_INDEX.md
