#!/bin/sh
# Rebuild what is generated from the store: TOPIC_INDEX.md, and one link per hippo skill in
# each agent skills folder (~/.claude/skills, ~/.agents/skills for Codex and pi). Adds links
# for new skills, removes links whose skill is gone, never touches anything it did not link.
# No arguments. Idempotent. Called by init_hippo.sh and finish_reflection.sh.
set -eu
cd "${HIPPO_DIR:-$HOME/.hippo}"
skills=$(pwd -P)/skills

{
  printf '# Topic index\n\nGenerated from line 2 of each topic file. Do not edit.\n\n'
  for f in topics/*.md; do if [ -e "$f" ]; then printf '%s\n' "- $f: $(sed -n 2p "$f")"; fi; done
} > TOPIC_INDEX.md

for d in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
  case $d in
    */.claude/*) [ -d "$HOME/.claude" ] || continue ;;
    *) [ -d "$HOME/.codex" ] || [ -d "$HOME/.pi/agent" ] || continue ;;
  esac
  mkdir -p "$d"
  for l in "$d"/* "$d"/.[!.]*; do
    [ -L "$l" ] || continue
    t=$(readlink "$l")
    case $t in "$skills"/*)
      if [ "$t" != "$skills/${l##*/}" ] || [ ! -f "$t/SKILL.md" ]; then rm "$l"; echo "unlinked $l"; fi ;;
    esac
  done
  for s in skills/*/; do
    [ -f "${s}SKILL.md" ] || continue
    n=${s#skills/}; n=${n%/}; l=$d/$n
    if [ -L "$l" ] && [ "$(readlink "$l")" = "$skills/$n" ]; then continue; fi
    if [ -e "$l" ] || [ -L "$l" ]; then echo "$l: taken by another skill; not linked" >&2; continue; fi
    ln -s "$skills/$n" "$l"; echo "linked $l"
  done
done
