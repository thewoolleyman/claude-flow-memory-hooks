#!/usr/bin/env bash
# run-tests.sh — Test runner. Dispatches by category or runs all.
#
# Usage: run-tests.sh [category...]
#   Categories: install, uninstall, hooks, validation, dry-run
#   No args = run all
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Colors ─────────────────────────────────────────────────────────────────────

if [ -t 1 ]; then
  BOLD='\033[1m'
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  RESET='\033[0m'
else
  BOLD='' GREEN='' RED='' RESET=''
fi

# ── Category to script mapping (portable, no associative arrays) ──────────────

category_to_script() {
  case "$1" in
    install)    printf 'integration/test-install.sh' ;;
    uninstall)  printf 'integration/test-uninstall.sh' ;;
    hooks)      printf 'integration/test-hooks.sh' ;;
    validation) printf 'integration/test-validation.sh' ;;
    dry-run)    printf 'integration/test-dry-run.sh' ;;
    *)          return 1 ;;
  esac
}

ALL_CATEGORIES="install uninstall hooks validation dry-run"

# ── Parse args ─────────────────────────────────────────────────────────────────

CATEGORIES=""
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      printf 'Usage: run-tests.sh [category...]\n'
      printf 'Categories: %s\n' "$ALL_CATEGORIES"
      printf 'No args = run all\n'
      exit 0
      ;;
    *)
      if ! category_to_script "$arg" >/dev/null 2>&1; then
        printf "Unknown category: %s\n" "$arg" >&2
        printf "Valid categories: %s\n" "$ALL_CATEGORIES" >&2
        exit 1
      fi
      CATEGORIES="$CATEGORIES $arg"
      ;;
  esac
done

if [ -z "$CATEGORIES" ]; then
  CATEGORIES="$ALL_CATEGORIES"
fi

# ── Run ────────────────────────────────────────────────────────────────────────

OVERALL_RC=0

printf "${BOLD}Running test categories:${RESET}%s\n\n" "$CATEGORIES"

for cat in $CATEGORIES; do
  script="$(category_to_script "$cat")"
  if ! bash "$TESTS_DIR/$script"; then
    OVERALL_RC=1
  fi
done

printf "\n${BOLD}══════════════════════════════════════${RESET}\n"
if [ "$OVERALL_RC" -eq 0 ]; then
  printf "${GREEN}${BOLD}All test suites passed.${RESET}\n"
else
  printf "${RED}${BOLD}Some test suites failed.${RESET}\n"
fi

exit "$OVERALL_RC"
