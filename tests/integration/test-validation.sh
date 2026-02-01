#!/usr/bin/env bash
# test-validation.sh — Input validation and edge case tests.
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$TESTS_DIR/lib/test-framework.sh"
source "$TESTS_DIR/lib/fixtures.sh"

print_section "Validation Tests"

# ── Test: rejects nonexistent path ─────────────────────────────────────────────

test_rejects_nonexistent_path() {
  local output rc=0
  output="$(run_install "/tmp/cfmh-does-not-exist" 2>&1)" || rc=$?

  [ "$rc" -ne 0 ] || return 1
  assert_output_contains "$output" "does not exist"
}
run_test "rejects nonexistent path" test_rejects_nonexistent_path

# ── Test: rejects missing settings.json ────────────────────────────────────────

test_rejects_missing_settings() {
  local dir
  dir="$(mktemp -d "${FIXTURE_PREFIX}-XXXXXX")"
  trap "teardown_fixture '$dir'" RETURN
  mkdir -p "$dir/.claude"
  # No settings.json

  local output rc=0
  output="$(run_install "$dir" 2>&1)" || rc=$?

  [ "$rc" -ne 0 ] || return 1
  assert_output_contains "$output" "settings.json"
}
run_test "rejects missing settings.json" test_rejects_missing_settings

# ── Test: rejects invalid JSON ─────────────────────────────────────────────────

test_rejects_invalid_json() {
  local dir; dir="$(create_fixture_with_invalid_json)"
  trap "teardown_fixture '$dir'" RETURN

  local output rc=0
  output="$(run_install "$dir" 2>&1)" || rc=$?

  [ "$rc" -ne 0 ] || return 1
  assert_output_contains "$output" "Invalid JSON"
}
run_test "rejects invalid JSON in settings.json" test_rejects_invalid_json

# ── Test: install help flag ────────────────────────────────────────────────────

test_install_help() {
  local output rc=0
  output="$(run_install --help 2>&1)" || rc=$?

  assert_exit_code "0" "$rc"
  assert_output_contains "$output" "Usage:"
  assert_output_contains "$output" "dry-run"
}
run_test "install -h shows help" test_install_help

# ── Test: no-args shows usage ──────────────────────────────────────────────────

test_no_args_usage() {
  local output rc=0
  output="$(run_install 2>&1)" || rc=$?

  [ "$rc" -ne 0 ] || return 1
  assert_output_contains "$output" "Missing required argument"
}
run_test "install with no args shows usage error" test_no_args_usage

# ── Test: uninstall help ───────────────────────────────────────────────────────

test_uninstall_help() {
  local output rc=0
  output="$(run_uninstall --help 2>&1)" || rc=$?

  assert_exit_code "0" "$rc"
  assert_output_contains "$output" "Usage:"
  assert_output_contains "$output" "remove-gitignore"
}
run_test "uninstall --help shows help" test_uninstall_help

# ── Test: rejects missing jq ──────────────────────────────────────────────────

test_rejects_missing_jq() {
  local dir; dir="$(create_minimal_fixture)"
  trap "teardown_fixture '$dir'" RETURN

  # Run install with PATH that excludes jq
  local output rc=0
  output="$(PATH="/usr/bin:/bin" run_install "$dir" 2>&1)" || rc=$?

  # This only fails if jq isn't in /usr/bin or /bin — skip if jq is there
  if command -v /usr/bin/jq >/dev/null 2>&1 || command -v /bin/jq >/dev/null 2>&1; then
    # jq is in a base path — we can't easily hide it; skip
    return 0
  fi

  [ "$rc" -ne 0 ] || return 1
  assert_output_contains "$output" "jq is required"
}
run_test "rejects when jq is missing" test_rejects_missing_jq

# ── Report ─────────────────────────────────────────────────────────────────────

report_results
