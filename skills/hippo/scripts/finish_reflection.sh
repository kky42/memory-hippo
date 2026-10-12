#!/bin/sh
# Final gate for a reflect: regenerate the topic index, doctor-check, commit with the
# folded notes in the message, delete the snapshot.
# Exit 0 done, 1 no snapshot, possible secret, or doctor failed (nothing committed, snapshot kept).
set -eu
dir=${HIPPO_DIR:-$HOME/.hippo}
here=$(cd "$(dirname "$0")" && pwd)
cd "$dir"
snap=PENDING.reflecting.md
[ -s "$snap" ] || { echo "no notes in $snap; run start_reflection.sh first" >&2; exit 1; }

# the notes go into git history; refuse anything that looks like a credential
if grep -nE 'gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|xox[abpr]-|-----BEGIN [A-Z ]*PRIVATE KEY' "$snap"; then
  echo "possible secret in $snap above; redact it there, then rerun" >&2; exit 1
fi

{
  printf '# Topic index\n\nGenerated from line 2 of each topic file. Do not edit.\n\n'
  for f in topics/*.md; do if [ -e "$f" ]; then printf '%s\n' "- $f: $(sed -n 2p "$f")"; fi; done
} > TOPIC_INDEX.md
"$here/doctor.sh" || { echo "refusing to commit: fix the problems above" >&2; exit 1; }
msg=$(mktemp)
{ echo "reflect: $(date +%F) $(hostname -s)"; echo; echo "notes folded:"; cat "$snap"; } > "$msg"
git add -A -- MEMORY.md TOPIC_INDEX.md topics
# commit even when no file changed, so dropped notes stay on record
git commit -q --allow-empty -F "$msg"
rm -f "$msg" "$snap"
echo "committed: $(git log -1 --format=%s)"
