# memory-hippo

Plain-file memory shared by every coding agent you use (Claude Code, Codex, pi, ...). No daemon, no MCP server, no search, no embeddings: markdown files in `~/.hippo`, a few instruction lines in each agent's global instructions, and one skill.

## How it works

- **Read:** at session start each agent reads `MEMORY.md`, `TOPIC_INDEX.md`, and today's daily notes, and opens topic files when relevant.
- **Write:** agents append one-line notes to `daily/YYYY-MM-DD.md` with shell `>>`. Nothing else is editable outside reflect.
- **Reflect:** the skill folds older daily notes into `topics/` and `MEMORY.md`, then deletes the consumed daily files.

```
~/.hippo/
  MEMORY.md         core memory every session needs
  TOPIC_INDEX.md    generated: one line per topic
  topics/*.md       user, feedback, project, reference seeds; reflect adds, merges, deletes
  daily/            untracked, machine-local, consumed by reflect
```

`~/.hippo` is a git repo that tracks only `MEMORY.md`, `TOPIC_INDEX.md`, and `topics/` - local history for audits and undo. Memory is single-machine by design: daily notes and reflections never leave the machine.

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
| reflect | merge daily notes into topics and MEMORY.md, then `finish_reflection.sh`: doctor gate, commit, delete the consumed daily files |

Run reflect only when you ask: "/hippo reflect". Nothing is scheduled.

## Budgets (enforced by `doctor.sh`, never shown to the model as targets)

| File | Limit |
|---|---|
| MEMORY.md | 4000 chars |
| each topic file | 8000 chars |
| topic files | 20 |
| daily files | none; reflect consumes them |

Counts use `wc -m` with `LC_ALL=en_US.UTF-8`; a system without that locale counts bytes, which makes the caps ~3x tighter for Chinese.

Codex users: the default sandbox blocks writes outside the workspace; add `~/.hippo` to `sandbox_workspace_write.writable_roots`.
