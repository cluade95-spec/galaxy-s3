# tiny test harness (sourced)
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "[PASS] $1"; }
bad()  { FAIL=$((FAIL+1)); echo "[FAIL] $1"; }
expect_ok()   { local n="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$n"; else bad "$n (expected success)"; fi; }
expect_fail() { local n="$1"; shift; if "$@" >/dev/null 2>&1; then bad "$n (expected failure, got success)"; else ok "$n"; fi; }
check() { local n="$1"; shift; if "$@"; then ok "$n"; else bad "$n"; fi; }      # check NAME CMD... : pass when CMD succeeds (output shown on failure by the caller)
finish() { echo "SUMMARY pass=$PASS fail=$FAIL"; [ "$FAIL" = 0 ]; }
# the real ubuntu-base tarball, if present (never downloaded by the tests): XU_REAL_TARBALL=/path, or the copy Phase 7 left in a scratch folder
real_tarball() {
  local t
  for t in "${XU_REAL_TARBALL:-}" /tmp/claude-0/*/*/scratchpad/ub16/ubuntu-base-16.04.6-base-amd64.tar.gz; do [ -f "$t" ] && { echo "$t"; return 0; }; done
  return 1
}
