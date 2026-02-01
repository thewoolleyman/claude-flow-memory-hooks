#!/usr/bin/env bash
# test-hooks.sh — Hook script behavior tests.
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
source "$TESTS_DIR/lib/test-framework.sh"
source "$TESTS_DIR/lib/fixtures.sh"

print_section "Hook Behavior Tests"

# ── Test: log-hook-event creates JSONL ─────────────────────────────────────────

test_log_hook_creates_jsonl() {
  local workdir
  workdir="$(mktemp -d "${FIXTURE_PREFIX}-XXXXXX")"
  trap "teardown_fixture '$workdir'" RETURN

  local payload='{"session_id":"test-sess","hook_event_name":"PreToolUse","tool_name":"Bash"}'
  printf '%s' "$payload" | (cd "$workdir" && bash "$PROJECT_ROOT/hooks/log-hook-event.sh")

  local logfile="$workdir/.claude-flow/learning/hook_logs/test-sess/PreToolUse.jsonl"
  assert_file_exists "$logfile"
  assert_file_contains "$logfile" '"ts"'
  assert_file_contains "$logfile" '"payload"'
}
run_test "log-hook-event creates JSONL file" test_log_hook_creates_jsonl

# ── Test: log-hook-event handles empty input ───────────────────────────────────

test_log_hook_empty_input() {
  local workdir
  workdir="$(mktemp -d "${FIXTURE_PREFIX}-XXXXXX")"
  trap "teardown_fixture '$workdir'" RETURN

  local rc=0
  printf '' | (cd "$workdir" && bash "$PROJECT_ROOT/hooks/log-hook-event.sh") || rc=$?

  assert_exit_code "0" "$rc"
}
run_test "log-hook-event handles empty input" test_log_hook_empty_input

# ── Test: build-context-bundle tool event ──────────────────────────────────────

test_bundle_tool_event() {
  local workdir
  workdir="$(mktemp -d "${FIXTURE_PREFIX}-XXXXXX")"
  trap "teardown_fixture '$workdir'" RETURN

  local payload='{"session_id":"test-sess","tool_name":"Read","tool_input":{"file_path":"/tmp/foo.txt"}}'
  printf '%s' "$payload" | (cd "$workdir" && bash "$PROJECT_ROOT/hooks/build-context-bundle.sh" --type tool)

  local bundle_dir="$workdir/.claude-flow/learning/context_bundles"
  # Should have created a .jsonl file
  local count
  count="$(find "$bundle_dir" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')"
  [ "$count" -gt 0 ] || { echo "no bundle file created" >&2; return 1; }

  # Should contain "read" operation
  local content
  content="$(cat "$bundle_dir"/*.jsonl)"
  assert_output_contains "$content" '"op":"read"'
}
run_test "build-context-bundle records tool events" test_bundle_tool_event

# ── Test: build-context-bundle prompt event ────────────────────────────────────

test_bundle_prompt_event() {
  local workdir
  workdir="$(mktemp -d "${FIXTURE_PREFIX}-XXXXXX")"
  trap "teardown_fixture '$workdir'" RETURN

  local payload='{"session_id":"test-sess","prompt":"How do I implement authentication?"}'
  printf '%s' "$payload" | (cd "$workdir" && bash "$PROJECT_ROOT/hooks/build-context-bundle.sh" --type prompt)

  local bundle_dir="$workdir/.claude-flow/learning/context_bundles"
  local content
  content="$(cat "$bundle_dir"/*.jsonl)"
  assert_output_contains "$content" '"op":"prompt"'
}
run_test "build-context-bundle records prompt events" test_bundle_prompt_event

# ── Test: build-context-bundle skips hook-infra commands ───────────────────────

test_bundle_skips_hook_infra() {
  local workdir
  workdir="$(mktemp -d "${FIXTURE_PREFIX}-XXXXXX")"
  trap "teardown_fixture '$workdir'" RETURN

  local payload='{"session_id":"test-sess","tool_name":"Bash","tool_input":{"command":"npx @claude-flow/cli@latest hooks pre-task"}}'
  printf '%s' "$payload" | (cd "$workdir" && bash "$PROJECT_ROOT/hooks/build-context-bundle.sh" --type tool)

  local bundle_dir="$workdir/.claude-flow/learning/context_bundles"
  # Should NOT have created a bundle entry for hook infrastructure
  local count
  count="$(find "$bundle_dir" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$count" -gt 0 ]; then
    local content
    content="$(cat "$bundle_dir"/*.jsonl)"
    assert_output_not_contains "$content" "claude-flow"
  fi
}
run_test "build-context-bundle skips hook-infra commands" test_bundle_skips_hook_infra

# ── Test: recall-memory skips short prompts ────────────────────────────────────

test_recall_skips_short() {
  local workdir
  workdir="$(mktemp -d "${FIXTURE_PREFIX}-XXXXXX")"
  trap "teardown_fixture '$workdir'" RETURN

  local payload='{"prompt":"hello"}'
  local output rc=0
  output="$(printf '%s' "$payload" | (cd "$workdir" && bash "$PROJECT_ROOT/hooks/recall-memory.sh") 2>&1)" || rc=$?

  assert_exit_code "0" "$rc"
  # Output should be empty for short prompts
  [ -z "$output" ] || assert_equals "" "$output" "should produce no output for short prompts"
}
run_test "recall-memory skips short prompts" test_recall_skips_short

# ── Test: recall-memory handles missing DB ─────────────────────────────────────

test_recall_missing_db() {
  local workdir
  workdir="$(mktemp -d "${FIXTURE_PREFIX}-XXXXXX")"
  trap "teardown_fixture '$workdir'" RETURN

  local payload='{"prompt":"How do I implement the search connector for elasticsearch?"}'
  local rc=0
  printf '%s' "$payload" | (cd "$workdir" && bash "$PROJECT_ROOT/hooks/recall-memory.sh") >/dev/null 2>&1 || rc=$?

  assert_exit_code "0" "$rc"
}
run_test "recall-memory handles missing DB gracefully" test_recall_missing_db

# ── Test: hook-bridge rejects unknown mode ─────────────────────────────────────

test_bridge_rejects_unknown() {
  local rc=0
  printf '{}' | bash "$PROJECT_ROOT/hooks/hook-bridge.sh" "nonexistent-mode" 2>/dev/null || rc=$?

  [ "$rc" -ne 0 ] || return 1
}
run_test "hook-bridge rejects unknown mode" test_bridge_rejects_unknown

# ── Test: hook-bridge rejects missing mode ─────────────────────────────────────

test_bridge_rejects_missing() {
  local rc=0
  printf '{}' | bash "$PROJECT_ROOT/hooks/hook-bridge.sh" 2>/dev/null || rc=$?

  [ "$rc" -ne 0 ] || return 1
}
run_test "hook-bridge rejects missing mode" test_bridge_rejects_missing

# ── Report ─────────────────────────────────────────────────────────────────────

report_results
