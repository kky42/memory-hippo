# memory-hippo

Plain-file memory and self-evolving skills shared by every coding agent you use (Claude Code, Codex, pi, ...). No daemon, no MCP server, no search, no embeddings: markdown files in `~/.hippo`, a few instruction lines in each agent's global instructions, and one skill.

## How it works

- **Read:** at session start each agent reads `MEMORY.md`, `TOPIC_INDEX.md`, and all pending notes, and opens topic files when relevant. Pending notes are newer than topics, so a fix takes effect for every new session right away.
- **Write:** agents append one-line notes to `PENDING.md` with shell `>>`. A correction quotes the wrong text: `- fix: "<wrong text>" -> <correct fact>`. A reusable procedure, or a change to one, is `- skill: <name>: <procedure or change>`. Nothing else is editable outside reflect.
- **Reflect:** the skill snapshots `PENDING.md`, folds the notes into `topics/`, `skills/`, and `MEMORY.md` (each fact in one place; fixes are grepped and applied everywhere), links each hippo skill into the agents' skill folders, and commits with the folded notes in the commit message.
- **Skills:** `~/.hippo/skills/<name>/` holds procedures (a `SKILL.md` plus any scripts and reference files). Each is linked as `~/.claude/skills/<name>` and `~/.agents/skills/<name>` (Codex, pi), so every agent loads it. Reflect creates, edits, merges, and removes them from `skill:` notes; links follow automatically.

```
~/.hippo/
  MEMORY.md              core memory every session needs: rules and pointers
  TOPIC_INDEX.md         generated: one line per topic
  topics/*.md            user, feedback, project, reference seeds; reflect adds, merges, deletes
  skills/<name>/         hippo skills: SKILL.md plus any scripts and references; linked into agents
  PENDING.md             untracked, append-only queue of notes waiting for reflect
  PENDING.reflecting.md  untracked, the snapshot a reflect is folding; exists only during one
```

`~/.hippo` is a git repo that tracks only `MEMORY.md`, `TOPIC_INDEX.md`, `topics/`, and `skills/` - local history for audits and undo. Raw notes are kept in the reflect commit messages: `git show <commit>` shows the notes next to the topic changes they produced, and `git log --grep <text>` finds where a note went. Memory is single-machine by design: notes and reflections never leave the machine.

## Install

Ask your agent: "Install https://github.com/kky42/memory-hippo and run its init workflow."

Or by hand:

```sh
npx skills add kky42/memory-hippo -g -y -a claude-code -a codex -a pi
~/.agents/skills/hippo/scripts/init_hippo.sh
```

## Scripts

Every workflow step that touches the store or agent files is a script, so agents never edit them by hand. None take arguments.

| Script | What it does |
|---|---|
| `init_hippo.sh` | idempotent: create the store if missing, install or refresh the [instruction block](skills/hippo/block.md) for every agent present (`~/.claude`, `~/.codex`, `~/.pi/agent`), run `sync_hippo.sh`, commit if doctor passes |
| `update_hippo.sh` | install the latest skill with `npx skills add`, print the skill diff, run the new `init_hippo.sh` |
| `start_reflection.sh` | snapshot `PENDING.md` into `PENDING.reflecting.md` |
| `sync_hippo.sh` | idempotent: regenerate `TOPIC_INDEX.md` and the skill links (add new, remove links whose skill is gone, never touch skills it did not link) |
| `finish_reflection.sh` | secret check on notes and store, run `sync_hippo.sh`, doctor gate, commit with the folded notes in the message, delete the snapshot |
| `doctor.sh` | read-only: every agent present carries exactly `block.md`, store layout, index, skill format and links, budgets, formats |

Workflows (init, update, reflect) are in [SKILL.md](skills/hippo/SKILL.md). Run them only when you ask, e.g. "/hippo reflect", "/hippo update". Nothing is scheduled.

Changing the store layout: describe it in SKILL.md and update the allowed entries in `doctor.sh`. There is no migration code: after `update_hippo.sh`, the agent reads the diff and the new SKILL.md, moves content wherever doctor says the store no longer fits, and reruns `init_hippo.sh` until it commits. Tracked files can be restored from the store's git history.

## Budgets (enforced by `doctor.sh`, never shown to the model as targets)

| File | Limit |
|---|---|
| MEMORY.md | 4000 chars |
| each topic file | 8000 chars |
| topic files | 20 |
| each skill's SKILL.md | 8000 chars; scripts and reference files unlimited |
| skills | 20 |
| PENDING.md | none enforced; agents suggest a reflect past ~40 lines |

`doctor.sh` also fails on date stamps like `(2026-10-12)` or `(2026-06-30~07-02)`, and warns on dates in the future and when the same path or issue number appears in more than one file.

Counts use `wc -m` with `LC_ALL=en_US.UTF-8`; a system without that locale counts bytes, which makes the caps ~3x tighter for Chinese.

Codex users: the default sandbox blocks writes outside the workspace; add `~/.hippo` to `sandbox_workspace_write.writable_roots`.
