#!/usr/bin/env bash
# test-framework.sh — Minimal test framework with colored output and assertions.
set -euo pipefail

# ── Colors ─────────────────────────────────────────────────────────────────────

if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' BOLD='' RESET=''
fi

# ── Counters ───────────────────────────────────────────────────────────────────

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_TEST=""
FAILURES=()

# ── Test Runner ────────────────────────────────────────────────────────────────

run_test() {
  local name="$1"
  shift
  CURRENT_TEST="$name"
  TESTS_RUN=$((TESTS_RUN + 1))

  if "$@" 2>&1; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf "  ${GREEN}✓${RESET} %s\n" "$name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILURES+=("$name")
    printf "  ${RED}✗${RESET} %s\n" "$name"
  fi
}

print_section() {
  printf "\n${BOLD}${BLUE}── %s ──${RESET}\n\n" "$1"
}

report_results() {
  printf "\n${BOLD}── Results ──${RESET}\n"
  printf "  Total:  %d\n" "$TESTS_RUN"
  printf "  ${GREEN}Passed: %d${RESET}\n" "$TESTS_PASSED"

  if [ "$TESTS_FAILED" -gt 0 ]; then
    printf "  ${RED}Failed: %d${RESET}\n" "$TESTS_FAILED"
    printf "\n${RED}Failed tests:${RESET}\n"
    for f in "${FAILURES[@]}"; do
      printf "  ${RED}✗${RESET} %s\n" "$f"
    done
    return 1
  else
    printf "  ${RED}Failed: 0${RESET}\n"
    printf "\n${GREEN}All tests passed.${RESET}\n"
    return 0
  fi
}

# ── Assertions ─────────────────────────────────────────────────────────────────

assert_equals() {
  local expected="$1" actual="$2" msg="${3:-}"
  if [ "$expected" != "$actual" ]; then
    printf "    expected: '%s'\n    actual:   '%s'\n" "$expected" "$actual" >&2
    [ -n "$msg" ] && printf "    %s\n" "$msg" >&2
    return 1
  fi
}

assert_file_exists() {
  local path="$1" msg="${2:-}"
  if [ ! -f "$path" ]; then
    printf "    file does not exist: %s\n" "$path" >&2
    [ -n "$msg" ] && printf "    %s\n" "$msg" >&2
    return 1
  fi
}

assert_file_not_exists() {
  local path="$1" msg="${2:-}"
  if [ -f "$path" ]; then
    printf "    file unexpectedly exists: %s\n" "$path" >&2
    [ -n "$msg" ] && printf "    %s\n" "$msg" >&2
    return 1
  fi
}

assert_dir_exists() {
  local path="$1" msg="${2:-}"
  if [ ! -d "$path" ]; then
    printf "    directory does not exist: %s\n" "$path" >&2
    [ -n "$msg" ] && printf "    %s\n" "$msg" >&2
    return 1
  fi
}

assert_file_contains() {
  local path="$1" pattern="$2" msg="${3:-}"
  if ! grep -q "$pattern" "$path" 2>/dev/null; then
    printf "    file '%s' does not contain: %s\n" "$path" "$pattern" >&2
    [ -n "$msg" ] && printf "    %s\n" "$msg" >&2
    return 1
  fi
}

assert_file_not_contains() {
  local path="$1" pattern="$2" msg="${3:-}"
  if grep -q "$pattern" "$path" 2>/dev/null; then
    printf "    file '%s' unexpectedly contains: %s\n" "$path" "$pattern" >&2
    [ -n "$msg" ] && printf "    %s\n" "$msg" >&2
    return 1
  fi
}

assert_exit_code() {
  local expected="$1" actual="$2" msg="${3:-}"
  if [ "$expected" != "$actual" ]; then
    printf "    expected exit code: %s, got: %s\n" "$expected" "$actual" >&2
    [ -n "$msg" ] && printf "    %s\n" "$msg" >&2
    return 1
  fi
}

assert_output_contains() {
  local output="$1" pattern="$2" msg="${3:-}"
  if ! printf '%s' "$output" | grep -q "$pattern"; then
    printf "    output does not contain: %s\n" "$pattern" >&2
    printf "    output was: %s\n" "$(printf '%s' "$output" | head -5)" >&2
    [ -n "$msg" ] && printf "    %s\n" "$msg" >&2
    return 1
  fi
}

assert_output_not_contains() {
  local output="$1" pattern="$2" msg="${3:-}"
  if printf '%s' "$output" | grep -q "$pattern"; then
    printf "    output unexpectedly contains: %s\n" "$pattern" >&2
    [ -n "$msg" ] && printf "    %s\n" "$msg" >&2
    return 1
  fi
}

assert_json_has_key() {
  local file="$1" key="$2" msg="${3:-}"
  if ! jq -e "$key" "$file" >/dev/null 2>&1; then
    printf "    JSON key '%s' not found in: %s\n" "$key" "$file" >&2
    [ -n "$msg" ] && printf "    %s\n" "$msg" >&2
    return 1
  fi
}

assert_file_executable() {
  local path="$1" msg="${2:-}"
  if [ ! -x "$path" ]; then
    printf "    file is not executable: %s\n" "$path" >&2
    [ -n "$msg" ] && printf "    %s\n" "$msg" >&2
    return 1
  fi
}
