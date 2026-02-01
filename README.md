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
git clone https://github.com/thewoolleyman/claude-flow-memory-hooks.git
cd claude-flow-memory-hooks
./scripts/install /path/to/your/project
```

### Dry run

Preview what would change without modifying anything:

```bash
./scripts/install /path/to/your/project --dry-run
```

## Uninstall

```bash
./scripts/uninstall /path/to/your/project
```

By default, `.gitignore` entries are preserved (they're harmless). To remove them:

```bash
./scripts/uninstall /path/to/your/project --remove-gitignore
```

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

## Design decisions

- **Copy, not symlink** — hooks run relative to the project root, so they must exist in the target repo
- **Idempotent** — running install twice produces the same result
- **`__managed_by` marker** — enables precise uninstall without touching user-defined hooks
- **jq required** — the only non-trivial dependency; validated before any changes are made
- **Gitignore kept on uninstall** — harmless to keep; opt-in removal with `--remove-gitignore`

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

Test categories: `install` (9), `uninstall` (8), `hooks` (9), `validation` (7), `dry-run` (5) — 38 tests total.
