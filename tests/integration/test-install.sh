#!/usr/bin/env bash
# test-install.sh — Install script integration tests.
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$TESTS_DIR/lib/test-framework.sh"
source "$TESTS_DIR/lib/fixtures.sh"

print_section "Install Tests"

# ── Test: copies all 4 hook files ──────────────────────────────────────────────

test_copies_all_hook_files() {
  local dir; dir="$(create_minimal_fixture)"
  trap "teardown_fixture '$dir'" RETURN

  run_install "$dir" >/dev/null

  assert_file_exists "$dir/.claude/hooks/hook-bridge.sh"
  assert_file_exists "$dir/.claude/hooks/log-hook-event.sh"
  assert_file_exists "$dir/.claude/hooks/recall-memory.sh"
  assert_file_exists "$dir/.claude/hooks/build-context-bundle.sh"
}
run_test "copies all 4 hook files" test_copies_all_hook_files

# ── Test: hook files are executable ────────────────────────────────────────────

test_hooks_executable() {
  local dir; dir="$(create_minimal_fixture)"
  trap "teardown_fixture '$dir'" RETURN

  run_install "$dir" >/dev/null

  assert_file_executable "$dir/.claude/hooks/hook-bridge.sh"
  assert_file_executable "$dir/.claude/hooks/log-hook-event.sh"
  assert_file_executable "$dir/.claude/hooks/recall-memory.sh"
  assert_file_executable "$dir/.claude/hooks/build-context-bundle.sh"
}
run_test "hook files are executable" test_hooks_executable

# ── Test: merges all 7 hook event types ────────────────────────────────────────

test_merges_all_hook_events() {
  local dir; dir="$(create_minimal_fixture)"
  trap "teardown_fixture '$dir'" RETURN

  run_install "$dir" >/dev/null

  local settings="$dir/.claude/settings.json"
  assert_json_has_key "$settings" '.hooks.PreToolUse'
  assert_json_has_key "$settings" '.hooks.PostToolUse'
  assert_json_has_key "$settings" '.hooks.UserPromptSubmit'
  assert_json_has_key "$settings" '.hooks.SessionStart'
  assert_json_has_key "$settings" '.hooks.Stop'
  assert_json_has_key "$settings" '.hooks.SessionEnd'
  assert_json_has_key "$settings" '.hooks.Notification'
}
run_test "merges all 7 hook event types" test_merges_all_hook_events

# ── Test: preserves existing hooks ─────────────────────────────────────────────

test_preserves_existing_hooks() {
  local dir; dir="$(create_fixture_with_existing_hooks)"
  trap "teardown_fixture '$dir'" RETURN

  run_install "$dir" >/dev/null

  local settings="$dir/.claude/settings.json"
  # User's "echo user-hook" should still be present
  assert_file_contains "$settings" "echo user-hook"
  # And managed hooks should also be present
  assert_file_contains "$settings" "__managed_by"
}
run_test "preserves existing hooks" test_preserves_existing_hooks

# ── Test: valid JSON after merge ───────────────────────────────────────────────

test_valid_json_after_merge() {
  local dir; dir="$(create_fixture_with_existing_hooks)"
  trap "teardown_fixture '$dir'" RETURN

  run_install "$dir" >/dev/null

  jq empty "$dir/.claude/settings.json"
}
run_test "produces valid JSON after merge" test_valid_json_after_merge

# ── Test: adds gitignore entries ───────────────────────────────────────────────

test_adds_gitignore_entries() {
  local dir; dir="$(create_minimal_fixture)"
  trap "teardown_fixture '$dir'" RETURN

  run_install "$dir" >/dev/null

  assert_file_exists "$dir/.gitignore"
  assert_file_contains "$dir/.gitignore" "BEGIN claude-flow-memory-hooks"
  assert_file_contains "$dir/.gitignore" "hook_logs"
  assert_file_contains "$dir/.gitignore" "context_bundles"
  assert_file_contains "$dir/.gitignore" "END claude-flow-memory-hooks"
}
run_test "adds gitignore entries" test_adds_gitignore_entries

# ── Test: preserves existing gitignore ─────────────────────────────────────────

test_preserves_existing_gitignore() {
  local dir; dir="$(create_fixture_with_gitignore)"
  trap "teardown_fixture '$dir'" RETURN

  run_install "$dir" >/dev/null

  assert_file_contains "$dir/.gitignore" "node_modules/"
  assert_file_contains "$dir/.gitignore" ".env"
  assert_file_contains "$dir/.gitignore" "BEGIN claude-flow-memory-hooks"
}
run_test "preserves existing gitignore content" test_preserves_existing_gitignore

# ── Test: idempotent ───────────────────────────────────────────────────────────

test_idempotent() {
  local dir; dir="$(create_minimal_fixture)"
  trap "teardown_fixture '$dir'" RETURN

  run_install "$dir" >/dev/null
  local first_json; first_json="$(cat "$dir/.claude/settings.json")"

  run_install "$dir" >/dev/null
  local second_json; second_json="$(cat "$dir/.claude/settings.json")"

  assert_equals "$first_json" "$second_json" "settings.json should be identical after second install"

  # Gitignore should have exactly one marker block
  local count
  count="$(grep -c "BEGIN claude-flow-memory-hooks" "$dir/.gitignore")"
  assert_equals "1" "$count" "should have exactly one marker block"
}
run_test "install is idempotent" test_idempotent

# ── Test: creates hooks directory ──────────────────────────────────────────────

test_creates_hooks_dir() {
  local dir; dir="$(create_minimal_fixture)"
  trap "teardown_fixture '$dir'" RETURN

  # Ensure no hooks dir exists
  rm -rf "$dir/.claude/hooks"

  run_install "$dir" >/dev/null

  assert_dir_exists "$dir/.claude/hooks"
}
run_test "creates .claude/hooks directory if missing" test_creates_hooks_dir

# ── Report ─────────────────────────────────────────────────────────────────────

report_results
