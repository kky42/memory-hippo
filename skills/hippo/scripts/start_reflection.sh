#!/bin/sh
# Snapshot the pending notes for a reflect: PENDING.md -> PENDING.reflecting.md.
# Notes appended during the reflect land in a fresh PENDING.md. A snapshot left by an
# aborted reflect is kept, and newer notes are appended after it.
# Exit 0 snapshot ready, 1 nothing to reflect.
set -eu
cd "${HIPPO_DIR:-$HOME/.hippo}"
if [ -s PENDING.md ]; then
  if [ -e PENDING.reflecting.md ]; then
    mv PENDING.md PENDING.moving.md
    cat PENDING.moving.md >> PENDING.reflecting.md
    rm PENDING.moving.md
  else
    mv PENDING.md PENDING.reflecting.md
  fi
fi
if [ ! -s PENDING.reflecting.md ]; then
  rm -f PENDING.reflecting.md
  echo "nothing to reflect"; exit 1
fi
echo "reflecting: $(grep -c '^- ' PENDING.reflecting.md || true) notes in PENDING.reflecting.md"
