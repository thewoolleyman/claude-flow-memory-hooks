# claude-flow-memory-hooks

A reusable install/uninstall overlay that adds memory, context-bundling, and observability hooks to any [Claude Code](https://docs.anthropic.com/en/docs/claude-code) project using [Claude Flow](https://github.com/ruvnet/claude-flow).

## What it does

Installs 4 hook scripts into your project's `.claude/hooks/` directory and wires them into `.claude/settings.json`:

| Hook | Purpose |
|------|---------|
| `hook-bridge.sh` | Routes Claude Code hook events to `claude-flow` CLI commands |
| `log-hook-event.sh` | Logs every hook event as JSONL for observability |
| `recall-memory.sh` | Searches memory DB and context bundles to enrich prompts |
| `build-context-bundle.sh` | Extracts curated context from tool/prompt events for recall |

These hooks are wired into all 7 Claude Code hook event types: `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `SessionStart`, `Stop`, `SessionEnd`, `Notification`.

## Prerequisites

- [jq](https://jqlang.github.io/jq/) (JSON processor)
- A Claude Code project with `.claude/settings.json`
- [Claude Flow CLI](https://github.com/ruvnet/claude-flow) (for hook-bridge functionality; hooks degrade gracefully without it)

## Install

```bash
git clone https://github.com/thewoolleyman/claude-flow-memory-hooks.git ~/workspace/claude-flow-memory-hooks
~/workspace/claude-flow-memory-hooks/scripts/install /path/to/your/project
```

### Dry run

Preview what would change without modifying anything:

```bash
~/workspace/claude-flow-memory-hooks/scripts/install /path/to/your/project --dry-run
```

## Uninstall

```bash
~/workspace/claude-flow-memory-hooks/scripts/uninstall /path/to/your/project
```

By default, `.gitignore` entries are preserved (they're harmless). To remove them:

```bash
~/workspace/claude-flow-memory-hooks/scripts/uninstall /path/to/your/project --remove-gitignore
```

## Architecture

### Why these hooks exist

Claude Flow V3's hook handlers (`hooksPostEdit`, `hooksPostTask`, `hooksPostCommand`) return success responses but write nothing to the database ([#1058](https://github.com/ruvnet/claude-flow/issues/1058)). The working persistence paths (`memory store`, `intelligence trajectory-*`) require explicit CLI calls. These hooks provide automatic persistence without replicating the upstream learning pipeline or adding native dependencies.

### Two-tier logging + automatic recall

Inspired by [elite-context-engineering](https://github.com/ruvnet/elite-context-engineering):

- **Tier 1 (raw firehose):** `log-hook-event.sh` logs every hook payload to per-session, per-event JSONL files. Full observability for debugging. Gitignored.
- **Tier 2 (curated signal):** `build-context-bundle.sh` extracts compact, relevant fields (file paths, commands, prompts) into context bundles that are committed to git and survive across clones.
- **Read side:** `recall-memory.sh` uses two search strategies (semantic SQLite search + keyword grep of context bundles) to inject relevant past context on every user prompt.

### Data flow

```
TIER 1 — RAW LOGGING (every hook event):
  Any hook fires (Pre/PostToolUse, UserPromptSubmit, etc.)
    -> log-hook-event.sh appends full JSON payload
    -> .claude-flow/learning/hook_logs/{session_id}/{HookName}.jsonl
    -> Gitignored — debugging and observability only

TIER 2 — CURATED BUNDLES (during session):
  PostToolUse fires for Read/Write/Edit/Bash/Task
    -> build-context-bundle.sh extracts compact fields
    -> Converts absolute paths to project-relative paths
    -> Skips hook-infrastructure commands (npx @claude-flow, .claude/hooks/)
    -> Appends to .claude-flow/learning/context_bundles/{DAY_HOUR}_{session_id}.jsonl
    -> Committed to git — survives across clones

  UserPromptSubmit fires
    -> build-context-bundle.sh --type prompt
    -> Records truncated prompt text to the same bundle file

READ PATH (every user prompt):
  User types a prompt
    -> recall-memory.sh reads prompt from stdin JSON
    -> Strategy 1: Semantic search via `memory search` (if .swarm/memory.db exists)
    -> Strategy 2: Keyword grep of context bundles (git-native fallback)
    -> Prints results to stdout
    -> Claude Code injects stdout into <system-reminder> tag
    -> Claude sees relevant past context before starting work

READ PATH (agent spawn):
  Task agent is about to be spawned (PreToolUse)
    -> recall-memory.sh searches for task-relevant context
    -> Results injected into Claude's context before agent starts
```

### Hook details

**`log-hook-event.sh`** (Tier 1 — raw logging)
- Reads the full hook stdin JSON
- Extracts `session_id` and `hook_event_name`
- Appends timestamped payload to `.claude-flow/learning/hook_logs/{session_id}/{HookName}.jsonl`
- Fast (<2ms) since it fires on every hook event via wildcard matcher

**`build-context-bundle.sh`** (Tier 2 — curated signal)
- Accepts `--type tool` (default) or `--type prompt`
- For tool events: extracts operation type, file paths, commands, task descriptions
- Converts absolute paths to project-relative paths
- Skips hook-infrastructure commands (`npx @claude-flow*`, `.claude/hooks/*`)
- Appends to `.claude-flow/learning/context_bundles/{DAY_HOUR}_{session_id}.jsonl`

Bundle entry formats:

| Tool | Bundle entry |
|------|-------------|
| `Read` | `{"op":"read","file":"internal/server/server.go"}` |
| `Write` | `{"op":"write","file":"internal/server/server.go"}` |
| `Edit`, `MultiEdit` | `{"op":"edit","file":"internal/server/server.go"}` |
| `Task` | `{"op":"task","desc":"Research X","agent":"researcher"}` |
| `Bash` | `{"op":"command","cmd":"go test ./..."}` |
| User prompt | `{"op":"prompt","text":"How do I implement OAuth?"}` |

**`recall-memory.sh`** (Read side — dual-strategy recall)
- Strategy 1: Semantic search via `.swarm/memory.db` (if it exists)
- Strategy 2: Keyword grep of context bundles (git-native fallback, always available)
- Skips prompts under 15 characters
- All errors suppressed — never blocks the prompt

**`hook-bridge.sh`** (Upstream bridge)
- Routes Claude Code hook events to `claude-flow` CLI commands
- Handles: pre-edit, pre-command, pre-task, post-edit, post-command, post-task, route, daemon-start, session-restore, stop-check, session-end, notify

### Forward compatibility

When upstream catches up (PR [#1059](https://github.com/ruvnet/claude-flow/pulls/1059)), these hooks become redundant. The hooks write to different namespaces than the CLI, so two writes are harmless. To remove cleanly, run `./scripts/uninstall`.

## What gets installed

### Files copied

```
<your-project>/.claude/hooks/
  hook-bridge.sh
  log-hook-event.sh
  recall-memory.sh
  build-context-bundle.sh
```

### Settings merged

Each hook entry in `.claude/settings.json` is tagged with `"__managed_by": "claude-flow-memory-hooks"` so uninstall can precisely remove only what install added, leaving your existing hooks untouched.

### Gitignore entries

A marker block is added to `.gitignore` for runtime state files:

```
# BEGIN claude-flow-memory-hooks
.claude-flow/learning/hook_logs/
.claude-flow/learning/context_bundles/
.swarm/state.json
.swarm/schema.sql
# END claude-flow-memory-hooks
```

## Verify

After installing, test the hooks:

```bash
# Test raw event logging (Tier 1)
echo '{"session_id":"test","hook_event_name":"PostToolUse","tool_name":"Edit"}' \
  | .claude/hooks/log-hook-event.sh
cat .claude-flow/learning/hook_logs/test/PostToolUse.jsonl
# expect: {"ts":"...","payload":{...}}

# Test context bundle for Edit event (Tier 2)
echo '{"session_id":"test","tool_name":"Edit","tool_input":{"file_path":"'$(pwd)'/internal/server/server.go"}}' \
  | .claude/hooks/build-context-bundle.sh --type tool
# expect: {"op":"edit","file":"internal/server/server.go"} (relative path)

# Test recall with grep fallback
echo '{"prompt":"How do hooks persist data to the memory database?"}' \
  | .claude/hooks/recall-memory.sh
# expect: "Context from past sessions:" with matching bundle lines

# Test short prompts are skipped
OUTPUT=$(echo '{"prompt":"hi"}' | .claude/hooks/recall-memory.sh)
test -z "$OUTPUT"  # expect: empty (skipped)
```

## Design decisions

- **Copy, not symlink** — hooks run relative to the project root, so they must exist in the target repo
- **Idempotent** — running install twice produces the same result
- **`__managed_by` marker** — enables precise uninstall without touching user-defined hooks
- **jq required** — the only non-trivial dependency; validated before any changes are made
- **Gitignore kept on uninstall** — harmless to keep; opt-in removal with `--remove-gitignore`
- **Git-native persistence** — context bundles are committed to git, surviving across clones without a database
- **No native dependencies** — pure bash + jq
- **Two search strategies** — semantic search (if DB available) + keyword grep (always available) means recall works on fresh clones

## Testing

```bash
# Run all tests
./tests/run-tests.sh

# Run a specific category
./tests/run-tests.sh install
./tests/run-tests.sh uninstall
./tests/run-tests.sh hooks
./tests/run-tests.sh validation
./tests/run-tests.sh dry-run
```

Test categories: `install` (9), `uninstall` (8), `hooks` (9), `validation` (7), `dry-run` (6) — 39 tests total.

## References

- [claude-flow repo](https://github.com/ruvnet/claude-flow)
- [elite-context-engineering repo](https://github.com/ruvnet/elite-context-engineering) (inspired the two-tier hook architecture)
- [Issue #1058 — Hook stubs](https://github.com/ruvnet/claude-flow/issues/1058)
- [PR #1059 — Hook persistence fix](https://github.com/ruvnet/claude-flow/pulls/1059)
- [Issue #967 — Backend split](https://github.com/ruvnet/claude-flow/issues/967)
