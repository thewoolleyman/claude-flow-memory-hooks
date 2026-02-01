#!/usr/bin/env bash
# common.sh — Shared constants, logging, and helpers for install/uninstall scripts.
set -euo pipefail

# ── Constants ──────────────────────────────────────────────────────────────────

HOOK_FILES=(
  hook-bridge.sh
  log-hook-event.sh
  recall-memory.sh
  build-context-bundle.sh
)

GITIGNORE_ENTRIES=(
  ".claude-flow/learning/hook_logs/"
  ".claude-flow/learning/context_bundles/"
  ".swarm/state.json"
  ".swarm/schema.sql"
)

MARKER_BEGIN="# BEGIN claude-flow-memory-hooks"
MARKER_END="# END claude-flow-memory-hooks"
MANAGED_BY_KEY="__managed_by"
MANAGED_BY_VALUE="claude-flow-memory-hooks"

# ── Logging ────────────────────────────────────────────────────────────────────

log_info()    { printf '[info]  %s\n' "$*"; }
log_warn()    { printf '[warn]  %s\n' "$*" >&2; }
log_error()   { printf '[error] %s\n' "$*" >&2; }
log_dry_run() { printf '[dry-run] %s\n' "$*"; }

# ── Paths ──────────────────────────────────────────────────────────────────────

get_project_root() {
  if [ -n "${CLAUDE_FLOW_MEMORY_HOOKS_ROOT:-}" ]; then
    printf '%s' "$CLAUDE_FLOW_MEMORY_HOOKS_ROOT"
  else
    # Walk up from this script to find the repo root (contains hooks/ dir)
    local dir
    dir="$(cd "$(dirname "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")" && pwd)"
    while [ "$dir" != "/" ]; do
      if [ -d "$dir/hooks" ] && [ -f "$dir/hooks/hook-bridge.sh" ]; then
        printf '%s' "$dir"
        return 0
      fi
      dir="$(dirname "$dir")"
    done
    log_error "Cannot locate claude-flow-memory-hooks project root"
    return 1
  fi
}

validate_target_project() {
  local target="$1"
  if [ ! -d "$target" ]; then
    log_error "Target directory does not exist: $target"
    return 1
  fi
  if [ ! -f "$target/.claude/settings.json" ]; then
    log_error "No .claude/settings.json found in: $target"
    return 1
  fi
  # Validate JSON
  if ! jq empty "$target/.claude/settings.json" 2>/dev/null; then
    log_error "Invalid JSON in $target/.claude/settings.json"
    return 1
  fi
  return 0
}

check_dependencies() {
  if ! command -v jq >/dev/null 2>&1; then
    log_error "jq is required but not installed. Install with: brew install jq (macOS) or apt-get install jq (Linux)"
    return 1
  fi
  return 0
}

# ── Hooks JSON Generation ─────────────────────────────────────────────────────

# Generates the hooks config entries that install adds to settings.json.
# Each entry carries __managed_by for precise uninstall.
generate_hooks_json() {
  cat <<'HOOKS_JSON'
{
  "PreToolUse": [
    {
      "matcher": "^(Write|Edit|MultiEdit)$",
      "hooks": [{"type": "command", "command": ".claude/hooks/hook-bridge.sh pre-edit", "timeout": 10000}],
      "__managed_by": "claude-flow-memory-hooks"
    },
    {
      "matcher": "^Bash$",
      "hooks": [{"type": "command", "command": ".claude/hooks/hook-bridge.sh pre-command", "timeout": 10000}],
      "__managed_by": "claude-flow-memory-hooks"
    },
    {
      "matcher": "^Task$",
      "hooks": [{"type": "command", "command": ".claude/hooks/hook-bridge.sh pre-task", "timeout": 10000}],
      "__managed_by": "claude-flow-memory-hooks"
    },
    {
      "matcher": "^Task$",
      "hooks": [{"type": "command", "command": ".claude/hooks/recall-memory.sh", "timeout": 10000}],
      "__managed_by": "claude-flow-memory-hooks"
    },
    {
      "matcher": "*",
      "hooks": [{"type": "command", "command": ".claude/hooks/log-hook-event.sh", "timeout": 2000}],
      "__managed_by": "claude-flow-memory-hooks"
    }
  ],
  "PostToolUse": [
    {
      "matcher": "^(Write|Edit|MultiEdit)$",
      "hooks": [{"type": "command", "command": ".claude/hooks/hook-bridge.sh post-edit", "timeout": 10000}],
      "__managed_by": "claude-flow-memory-hooks"
    },
    {
      "matcher": "^Bash$",
      "hooks": [{"type": "command", "command": ".claude/hooks/hook-bridge.sh post-command", "timeout": 10000}],
      "__managed_by": "claude-flow-memory-hooks"
    },
    {
      "matcher": "^Task$",
      "hooks": [{"type": "command", "command": ".claude/hooks/hook-bridge.sh post-task", "timeout": 10000}],
      "__managed_by": "claude-flow-memory-hooks"
    },
    {
      "matcher": "^(Read|Write|Edit|MultiEdit|Bash|Task)$",
      "hooks": [{"type": "command", "command": ".claude/hooks/build-context-bundle.sh --type tool", "timeout": 2000}],
      "__managed_by": "claude-flow-memory-hooks"
    },
    {
      "matcher": "*",
      "hooks": [{"type": "command", "command": ".claude/hooks/log-hook-event.sh", "timeout": 2000}],
      "__managed_by": "claude-flow-memory-hooks"
    }
  ],
  "UserPromptSubmit": [
    {
      "hooks": [
        {"type": "command", "command": ".claude/hooks/recall-memory.sh", "timeout": 10000},
        {"type": "command", "command": ".claude/hooks/build-context-bundle.sh --type prompt", "timeout": 2000},
        {"type": "command", "command": ".claude/hooks/hook-bridge.sh route", "timeout": 10000},
        {"type": "command", "command": ".claude/hooks/log-hook-event.sh", "timeout": 2000}
      ],
      "__managed_by": "claude-flow-memory-hooks"
    }
  ],
  "SessionStart": [
    {
      "hooks": [
        {"type": "command", "command": ".claude/hooks/log-hook-event.sh", "timeout": 2000},
        {"type": "command", "command": ".claude/hooks/hook-bridge.sh daemon-start", "timeout": 10000},
        {"type": "command", "command": ".claude/hooks/hook-bridge.sh session-restore", "timeout": 15000}
      ],
      "__managed_by": "claude-flow-memory-hooks"
    }
  ],
  "Stop": [
    {
      "hooks": [
        {"type": "command", "command": ".claude/hooks/hook-bridge.sh stop-check", "timeout": 5000},
        {"type": "command", "command": ".claude/hooks/log-hook-event.sh", "timeout": 2000}
      ],
      "__managed_by": "claude-flow-memory-hooks"
    }
  ],
  "SessionEnd": [
    {
      "hooks": [
        {"type": "command", "command": ".claude/hooks/log-hook-event.sh", "timeout": 2000},
        {"type": "command", "command": ".claude/hooks/hook-bridge.sh session-end", "timeout": 10000}
      ],
      "__managed_by": "claude-flow-memory-hooks"
    }
  ],
  "Notification": [
    {
      "hooks": [
        {"type": "command", "command": ".claude/hooks/hook-bridge.sh notify", "timeout": 5000},
        {"type": "command", "command": ".claude/hooks/log-hook-event.sh", "timeout": 2000}
      ],
      "__managed_by": "claude-flow-memory-hooks"
    }
  ]
}
HOOKS_JSON
}
