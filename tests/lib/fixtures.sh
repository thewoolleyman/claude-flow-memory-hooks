#!/usr/bin/env bash
# fixtures.sh — Test fixture helpers for creating/tearing down temp projects.
set -euo pipefail

FIXTURE_PREFIX="/tmp/cfmh-test"

# ── Fixture Creators ──────────────────────────────────────────────────────────

# Creates a minimal fixture with just .claude/settings.json (empty hooks).
# Prints the fixture path.
create_minimal_fixture() {
  local dir
  dir="$(mktemp -d "${FIXTURE_PREFIX}-XXXXXX")"
  mkdir -p "$dir/.claude"
  cat > "$dir/.claude/settings.json" <<'JSON'
{
  "hooks": {}
}
JSON
  printf '%s' "$dir"
}

# Creates a fixture with existing user-defined hooks already in settings.json.
create_fixture_with_existing_hooks() {
  local dir
  dir="$(mktemp -d "${FIXTURE_PREFIX}-XXXXXX")"
  mkdir -p "$dir/.claude"
  cat > "$dir/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "^Bash$",
        "hooks": [{"type": "command", "command": "echo user-hook", "timeout": 5000}]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [{"type": "command", "command": "echo post-user", "timeout": 5000}]
      }
    ]
  }
}
JSON
  printf '%s' "$dir"
}

# Creates a fixture that already has managed hooks installed.
create_fixture_with_installed_hooks() {
  local dir
  dir="$(create_minimal_fixture)"

  # Run install against it
  run_install "$dir" >/dev/null 2>&1

  printf '%s' "$dir"
}

# Creates a fixture with a .gitignore that has existing content.
create_fixture_with_gitignore() {
  local dir
  dir="$(create_minimal_fixture)"
  cat > "$dir/.gitignore" <<'EOF'
node_modules/
.env
EOF
  printf '%s' "$dir"
}

# Creates a fixture with invalid JSON in settings.json.
create_fixture_with_invalid_json() {
  local dir
  dir="$(mktemp -d "${FIXTURE_PREFIX}-XXXXXX")"
  mkdir -p "$dir/.claude"
  printf 'this is not json{' > "$dir/.claude/settings.json"
  printf '%s' "$dir"
}

# ── Teardown ───────────────────────────────────────────────────────────────────

teardown_fixture() {
  local dir="$1"
  if [ -d "$dir" ] && [[ "$dir" == ${FIXTURE_PREFIX}* ]]; then
    rm -rf "$dir"
  fi
}

teardown_all_fixtures() {
  rm -rf "${FIXTURE_PREFIX}"-* 2>/dev/null || true
}

# ── Script Runners ─────────────────────────────────────────────────────────────

# Locate project root (parent of tests/)
_project_root() {
  local dir
  dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  printf '%s' "$dir"
}

run_install() {
  "$(_project_root)/scripts/install" "$@"
}

run_uninstall() {
  "$(_project_root)/scripts/uninstall" "$@"
}
