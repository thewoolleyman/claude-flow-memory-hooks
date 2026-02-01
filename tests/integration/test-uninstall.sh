#!/usr/bin/env bash
# test-uninstall.sh — Uninstall script integration tests.
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$TESTS_DIR/lib/test-framework.sh"
source "$TESTS_DIR/lib/fixtures.sh"

print_section "Uninstall Tests"

# ── Test: removes all 4 hook files ────────────────────────────────────────────

test_removes_all_hook_files() {
  local dir; dir="$(create_fixture_with_installed_hooks)"
  trap "teardown_fixture '$dir'" RETURN

  run_uninstall "$dir" >/dev/null

  assert_file_not_exists "$dir/.claude/hooks/hook-bridge.sh"
  assert_file_not_exists "$dir/.claude/hooks/log-hook-event.sh"
  assert_file_not_exists "$dir/.claude/hooks/recall-memory.sh"
  assert_file_not_exists "$dir/.claude/hooks/build-context-bundle.sh"
}
run_test "removes all 4 hook files" test_removes_all_hook_files

# ── Test: unmerges hooks from JSON ─────────────────────────────────────────────

test_unmerges_hooks() {
  local dir; dir="$(create_fixture_with_installed_hooks)"
  trap "teardown_fixture '$dir'" RETURN

  run_uninstall "$dir" >/dev/null

  assert_file_not_contains "$dir/.claude/settings.json" "__managed_by"
  assert_file_not_contains "$dir/.claude/settings.json" "hook-bridge.sh"
}
run_test "removes managed hook entries from JSON" test_unmerges_hooks

# ── Test: preserves user hooks ─────────────────────────────────────────────────

test_preserves_user_hooks() {
  local dir; dir="$(create_fixture_with_existing_hooks)"
  trap "teardown_fixture '$dir'" RETURN

  run_install "$dir" >/dev/null
  run_uninstall "$dir" >/dev/null

  assert_file_contains "$dir/.claude/settings.json" "echo user-hook"
  assert_file_contains "$dir/.claude/settings.json" "echo post-user"
}
run_test "preserves user-defined hooks" test_preserves_user_hooks

# ── Test: valid JSON after unmerge ─────────────────────────────────────────────

test_valid_json_after_unmerge() {
  local dir; dir="$(create_fixture_with_installed_hooks)"
  trap "teardown_fixture '$dir'" RETURN

  run_uninstall "$dir" >/dev/null

  jq empty "$dir/.claude/settings.json"
}
run_test "produces valid JSON after unmerge" test_valid_json_after_unmerge

# ── Test: gitignore preserved by default ───────────────────────────────────────

test_gitignore_preserved_by_default() {
  local dir; dir="$(create_fixture_with_installed_hooks)"
  trap "teardown_fixture '$dir'" RETURN

  run_uninstall "$dir" >/dev/null

  assert_file_contains "$dir/.gitignore" "BEGIN claude-flow-memory-hooks"
}
run_test "gitignore preserved by default" test_gitignore_preserved_by_default

# ── Test: gitignore removed with flag ──────────────────────────────────────────

test_gitignore_removed_with_flag() {
  local dir; dir="$(create_fixture_with_installed_hooks)"
  trap "teardown_fixture '$dir'" RETURN

  run_uninstall "$dir" --remove-gitignore >/dev/null

  assert_file_not_contains "$dir/.gitignore" "BEGIN claude-flow-memory-hooks"
}
run_test "gitignore removed with --remove-gitignore" test_gitignore_removed_with_flag

# ── Test: hooks directory preserved ────────────────────────────────────────────

test_hooks_dir_preserved() {
  local dir; dir="$(create_fixture_with_installed_hooks)"
  trap "teardown_fixture '$dir'" RETURN

  run_uninstall "$dir" >/dev/null

  assert_dir_exists "$dir/.claude/hooks"
}
run_test "hooks directory preserved" test_hooks_dir_preserved

# ── Test: handles already-uninstalled ──────────────────────────────────────────

test_already_uninstalled() {
  local dir; dir="$(create_minimal_fixture)"
  trap "teardown_fixture '$dir'" RETURN

  # Uninstall from a project that never had hooks installed
  local output; output="$(run_uninstall "$dir" 2>&1)" || true

  # Should not error
  assert_output_contains "$output" "complete"
}
run_test "handles already-uninstalled gracefully" test_already_uninstalled

# ── Report ─────────────────────────────────────────────────────────────────────

report_results
