#!/bin/sh
# Final gate for a reflect: secret check, sync_hippo.sh (topic index, skill links), doctor,
# commit with the folded notes in the message, delete the snapshot.
# Exit 0 done, 1 no snapshot, possible secret, or doctor failed (nothing committed, snapshot kept).
set -eu
dir=${HIPPO_DIR:-$HOME/.hippo}
here=$(cd "$(dirname "$0")" && pwd)
cd "$dir"
snap=PENDING.reflecting.md
[ -s "$snap" ] || { echo "no notes in $snap; run start_reflection.sh first" >&2; exit 1; }

# the notes and the store go into git history; refuse anything that looks like a credential
if grep -rnE 'gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|hf_[A-Za-z0-9]{20,}|glpat-[A-Za-z0-9_-]{20,}|npm_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|xox[abpr]-|-----BEGIN [A-Z ]*PRIVATE KEY' "$snap" MEMORY.md topics skills; then
  echo "possible secret above; redact it, then rerun" >&2; exit 1
fi

"$here/sync_hippo.sh"
"$here/doctor.sh" || { echo "refusing to commit: fix the problems above" >&2; exit 1; }
msg=$(mktemp)
{ echo "reflect: $(date +%F) $(hostname -s)"; echo; echo "notes folded:"; cat "$snap"; } > "$msg"
git add -A -- MEMORY.md TOPIC_INDEX.md topics skills
# commit even when no file changed, so dropped notes stay on record
git commit -q --allow-empty -F "$msg"
rm -f "$msg" "$snap"
echo "committed: $(git log -1 --format=%s)"
