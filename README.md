# memory-hippo

Plain-file memory shared by every coding agent you use (Claude Code, Codex, pi, ...). No daemon, no MCP server, no search, no embeddings: markdown files in `~/.hippo`, a few instruction lines in each agent's global instructions, and one skill.

## How it works

- **Read:** at session start each agent reads `MEMORY.md`, `TOPIC_INDEX.md`, and all pending notes, and opens topic files when relevant. Pending notes are newer than topics, so a fix takes effect for every new session right away.
- **Write:** agents append one-line notes to `PENDING.md` with shell `>>`. A correction quotes the wrong text: `- fix: "<wrong text>" -> <correct fact>`. Nothing else is editable outside reflect.
- **Reflect:** the skill snapshots `PENDING.md`, folds the notes into `topics/` and `MEMORY.md` (each fact in one place; fixes are grepped and applied everywhere), and commits with the folded notes in the commit message.

```
~/.hippo/
  MEMORY.md              core memory every session needs: rules and pointers
  TOPIC_INDEX.md         generated: one line per topic
  topics/*.md            user, feedback, project, reference seeds; reflect adds, merges, deletes
  PENDING.md             untracked, append-only queue of notes waiting for reflect
  PENDING.reflecting.md  untracked, the snapshot a reflect is folding; exists only during one
```

`~/.hippo` is a git repo that tracks only `MEMORY.md`, `TOPIC_INDEX.md`, and `topics/` - local history for audits and undo. Raw notes are kept in the reflect commit messages: `git show <commit>` shows the notes next to the topic changes they produced, and `git log --grep <text>` finds where a note went. Memory is single-machine by design: notes and reflections never leave the machine.

## Install

Ask your agent: "Install https://github.com/kky42/memory-hippo and run its init workflow."

Or by hand:

```sh
npx skills add kky42/memory-hippo -g -a claude-code -a codex -a pi
~/.claude/skills/hippo/scripts/init.sh ~/.claude/CLAUDE.md ~/.codex/AGENTS.md ~/.pi/agent/AGENTS.md
# or ~/.agents/skills/hippo/scripts/init.sh, wherever the skill landed
```

Manual copy also works: put `skills/hippo` into `~/.agents/skills/` and `~/.claude/skills/`. Then run `init.sh` as above.

`init.sh` creates the store, then adds the [injection block](skills/hippo/block.md) to the end of each file you pass it. If a `<memory-hippo>` block is already there, it replaces that block, so re-running after an update refreshes it.

## Workflows (in SKILL.md)

| Workflow | What it does |
|---|---|
| init | install the skill (re-running updates it: show the diff, get approval), run `init.sh` on the agent files you choose (adds or refreshes the block) |
| reflect | `start_reflection.sh` snapshots `PENDING.md`; fold the notes into topics and MEMORY.md; `finish_reflection.sh`: secret check, doctor gate, commit with the notes in the message, delete the snapshot |

Run reflect only when you ask: "/hippo reflect". Nothing is scheduled.

## Budgets (enforced by `doctor.sh`, never shown to the model as targets)

| File | Limit |
|---|---|
| MEMORY.md | 4000 chars |
| each topic file | 8000 chars |
| topic files | 20 |
| PENDING.md | none enforced; agents suggest a reflect past ~40 lines |

`doctor.sh` also fails on date stamps like `(2026-10-12)`, and warns on dates in the future and when the same path or issue number appears in more than one file.

Counts use `wc -m` with `LC_ALL=en_US.UTF-8`; a system without that locale counts bytes, which makes the caps ~3x tighter for Chinese.

Codex users: the default sandbox blocks writes outside the workspace; add `~/.hippo` to `sandbox_workspace_write.writable_roots`.
