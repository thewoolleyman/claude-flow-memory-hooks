#!/usr/bin/env bash
# test-dry-run.sh — Dry-run mode tests.
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$TESTS_DIR/lib/test-framework.sh"
source "$TESTS_DIR/lib/fixtures.sh"

print_section "Dry-Run Tests"

# ── Test: no files copied ──────────────────────────────────────────────────────

test_no_files_copied() {
  local dir; dir="$(create_minimal_fixture)"
  trap "teardown_fixture '$dir'" RETURN

  run_install "$dir" --dry-run >/dev/null

  assert_file_not_exists "$dir/.claude/hooks/hook-bridge.sh"
  assert_file_not_exists "$dir/.claude/hooks/log-hook-event.sh"
  assert_file_not_exists "$dir/.claude/hooks/recall-memory.sh"
  assert_file_not_exists "$dir/.claude/hooks/build-context-bundle.sh"
}
run_test "dry-run copies no files" test_no_files_copied

# ── Test: settings unchanged ──────────────────────────────────────────────────

test_settings_unchanged() {
  local dir; dir="$(create_minimal_fixture)"
  trap "teardown_fixture '$dir'" RETURN

  local before; before="$(cat "$dir/.claude/settings.json")"
  run_install "$dir" --dry-run >/dev/null
  local after; after="$(cat "$dir/.claude/settings.json")"

  assert_equals "$before" "$after" "settings.json should be unchanged"
}
run_test "dry-run leaves settings.json unchanged" test_settings_unchanged

# ── Test: no gitignore created ─────────────────────────────────────────────────

test_no_gitignore_created() {
  local dir; dir="$(create_minimal_fixture)"
  trap "teardown_fixture '$dir'" RETURN

  # Ensure no .gitignore
  rm -f "$dir/.gitignore"

  run_install "$dir" --dry-run >/dev/null

  assert_file_not_exists "$dir/.gitignore"
}
run_test "dry-run does not create .gitignore" test_no_gitignore_created

# ── Test: shows planned actions ────────────────────────────────────────────────

test_shows_planned_actions() {
  local dir; dir="$(create_minimal_fixture)"
  trap "teardown_fixture '$dir'" RETURN

  local output
  output="$(run_install "$dir" --dry-run 2>&1)"

  assert_output_contains "$output" "dry-run"
  assert_output_contains "$output" "Would"
}
run_test "dry-run shows planned actions" test_shows_planned_actions

# ── Test: does not say "Would create" when hooks dir exists ────────────────────

test_no_create_msg_when_dir_exists() {
  local dir; dir="$(create_minimal_fixture)"
  trap "teardown_fixture '$dir'" RETURN

  mkdir -p "$dir/.claude/hooks"

  local output
  output="$(run_install "$dir" --dry-run 2>&1)"

  assert_output_not_contains "$output" "Would create directory"
}
run_test "dry-run does not say 'Would create' when hooks dir exists" test_no_create_msg_when_dir_exists

# ── Test: exit code 0 ─────────────────────────────────────────────────────────

test_exit_code_zero() {
  local dir; dir="$(create_minimal_fixture)"
  trap "teardown_fixture '$dir'" RETURN

  local rc=0
  run_install "$dir" --dry-run >/dev/null 2>&1 || rc=$?

  assert_exit_code "0" "$rc"
}
run_test "dry-run exits with code 0" test_exit_code_zero

# ── Report ─────────────────────────────────────────────────────────────────────

report_results
