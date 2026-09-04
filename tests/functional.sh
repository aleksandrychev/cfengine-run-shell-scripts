#!/usr/bin/env bash
# Functional test of the run-shell-scripts module.
#
# Runs cf-agent with the policy sets built by tests/build-policies.sh and checks
# that the configured scripts actually ran. Must run as root on a Linux host
# with CFEngine installed (for example a GitHub Actions runner, or the
# container started by tests/run-locally.sh).
#
# Environment:
#   POLICIES  Directory with the built policy sets (default: tests/out/policies)
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
policies="${POLICIES:-$here/out/policies}"
export PATH="/var/cfengine/bin:$PATH"

[ "$(id -u)" = "0" ] || { echo "must run as root" >&2; exit 1; }
command -v cf-agent >/dev/null || { echo "cf-agent not found" >&2; exit 1; }
[ -d "$policies/single" ] || { echo "policy sets not found in $policies, run tests/build-policies.sh" >&2; exit 1; }

fail() { echo "FAIL: $*" >&2; exit 1; }

use_policy() {
  rm -rf /var/cfengine/inputs
  cp -R "$policies/$1" /var/cfengine/inputs
}
run_agent() {
  # $1 (optional): extended grep pattern for error lines that are expected
  # and should not fail the test (e.g. a script that deliberately exits non-zero).
  local allowed="${1:-}"
  cf-agent -KI -f /var/cfengine/inputs/promises.cf > /tmp/agent.log 2>&1 || true
  grep -E "run-shell-scripts|error" /tmp/agent.log || true
  local unexpected
  unexpected="$(grep "error:" /tmp/agent.log || true)"
  if [ -n "$allowed" ]; then
    unexpected="$(echo "$unexpected" | grep -vE "$allowed" || true)"
  fi
  [ -z "$unexpected" ] || fail "agent run had unexpected errors: $unexpected"
}
line_count() { grep -Fxc "$1" "$LOG_FILE" 2>/dev/null || true; }

# No background agent runs during the test: stop CFEngine daemons if the
# package started them (the test policy sets also give cf-execd an empty schedule).
systemctl stop cfengine3 2>/dev/null || true
pkill -x cf-execd 2>/dev/null || true
pkill -x cf-serverd 2>/dev/null || true
pkill -x cf-monitord 2>/dev/null || true

LOG_FILE="$(mktemp)"
export LOG_FILE
rm -f "$LOG_FILE"

echo "### 1. no scripts configured: no error, informational report only"
use_policy no-scripts
run_agent
grep -q "no scripts configured" /tmp/agent.log || fail "missing 'no scripts configured' report"
[ -f "$LOG_FILE" ] && fail "a script ran even though none were configured"
echo "OK"

echo "### 2. single script: runs and writes its output"
use_policy single
run_agent
[ "$(line_count "one ran")" = "1" ] || fail "one.sh did not run exactly once"
echo "OK"

echo "### 3. scripts run again on every subsequent agent run when ifelapsed=0"
run_agent
[ "$(line_count "one ran")" = "2" ] || fail "one.sh did not re-run on the second agent execution"
echo "OK"

echo "### 4. multiple scripts: all run, a failing script doesn't stop the others"
rm -f "$LOG_FILE"
use_policy multiple
run_agent "promiser '/bin/bash' -- an error occurred, returned 1"
[ "$(line_count "one ran")" = "1" ] || fail "one.sh did not run"
[ "$(line_count "two ran")" = "1" ] || fail "two.sh did not run"
[ "$(line_count "failing ran")" = "1" ] || fail "failing.sh did not run"
echo "OK"

echo "### 5. a script without the executable bit set still runs"
rm -f "$LOG_FILE"
use_policy no-exec-bit
script_path="$(find /var/cfengine/inputs -name 'no-exec-bit.sh')"
[ -x "$script_path" ] && fail "test fixture unexpectedly has the executable bit set"
run_agent
[ "$(line_count "no-exec-bit ran")" = "1" ] || fail "no-exec-bit.sh did not run"
echo "OK"

echo "### 6. a false condition disables all scripts"
rm -f "$LOG_FILE"
use_policy condition-false
run_agent
[ -f "$LOG_FILE" ] && fail "one.sh ran despite condition being false"
echo "OK"

rm -f "$LOG_FILE"
echo "ALL TESTS PASSED"
