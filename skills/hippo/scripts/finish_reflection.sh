#!/bin/sh
# Final gate for a reflect: regenerate the topic index, doctor-check, commit, delete consumed daily files.
# Usage: finish_reflection.sh YYYY-MM-DD   (D from reflect step 2, the date the daily list was made)
# Exit 0 done, 1 bad usage or doctor failed (nothing committed, daily files kept), 2 committed locally but sync failed.
set -eu
dir=${HIPPO_DIR:-$HOME/.hippo}
here=$(cd "$(dirname "$0")" && pwd)
case ${1:-} in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) cutoff=$1 ;;
  *) echo "usage: finish_reflection.sh YYYY-MM-DD" >&2; exit 1 ;; esac
cd "$dir"
msg="reflect: $cutoff $(hostname -s)"

"$here/update_topic_index.sh"
"$here/doctor.sh" || { echo "refusing to commit: fix the problems above" >&2; exit 1; }
git add -A -- MEMORY.md TOPIC_INDEX.md topics
if git diff --cached --quiet; then echo "nothing to commit"
else git commit -qm "$msg"; echo "committed: $msg"; fi

# the notes are folded in: daily files dated before the cutoff are consumed
for f in daily/*.md; do
  b=${f#daily/}
  case $b in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*.md) ;; *) continue ;; esac
  if [ "$b" \< "$cutoff" ]; then rm -f "$f"; echo "consumed daily/$b"; fi
done

[ -n "$(git remote)" ] || exit 0
if ! git pull -q --rebase --autostash; then
  git rebase --abort 2>/dev/null || true
  echo "sync failed: remote has conflicting changes" >&2
  exit 2
fi
git push -q || { echo "sync failed: push rejected" >&2; exit 2; }
echo "synced"
