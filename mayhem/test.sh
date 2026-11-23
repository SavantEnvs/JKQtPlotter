#!/usr/bin/env bash
#
# mayhem/test.sh — RUN JKQtPlotter's own QtTest unit tests (built by mayhem/build.sh into
# build-tests/output). Counts come from each binary's QtTest "Totals:" line, not its exit code;
# a binary that prints no Totals line counts as failed.
#
# IMPORTANT:
#  * Must assert BEHAVIOR/OUTPUT, not just exit status. The oracle has to check asserted values /
#    golden-output diffs / known-answer results — so a PATCH that "fixes" a bug by making the program
#    exit(0) (or any no-op) FAILS here. Running inputs and checking only "exit 0 / didn't crash" is
#    NOT a functional test (it's trivially reward-hackable) — use the project's real assertion suite.
#  * Do NOT build here — mayhem/build.sh already compiled the test suite (with the project's normal
#    flags). This script only RUNS the pre-built tests and reports counts. If the test runner is
#    missing, that's a build.sh bug — fail loudly rather than silently rebuilding.
#  * REQUIRED OUTPUT — a CTRF (https://ctrf.io) summary so Mayhem/the PATCH grader reads the counts:
#      - writes a CTRF JSON report to ${CTRF_REPORT:-$SRC/ctrf-report.json}, and
#      - prints a one-line `CTRF {...}` marker to stdout (same JSON, compact).
#    Only `results.summary` (with tests/passed/failed/pending/skipped/other) is required.
#    Use the emit_ctrf helper below; it computes tests = passed+failed+skipped and sets the exit
#    code (0 iff failed==0). Map your framework's output to passed/failed/skipped.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"   # build parallelism; env-overridable, falls back to nproc (use -j"$MAYHEM_JOBS")
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
# Writes a CTRF report (file + stdout `CTRF {...}` marker) and returns non-zero iff failed>0.
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

export QT_QPA_PLATFORM=offscreen
OUT="$SRC/build-tests/output"
TESTS=(JKQTPStringTools_test JKQTPCSSParser_test JKQTPDataCache_test jkqtpstatisticstools_test test_jkqtpdatastore)
P=0; F=0; S=0
for t in "${TESTS[@]}"; do
  if [ ! -x "$OUT/$t" ]; then echo "MISSING test binary $OUT/$t (build.sh bug)" >&2; F=$((F+1)); continue; fi
  log=$("$OUT/$t" 2>&1); rc=$?
  tot=$(printf '%s\n' "$log" | grep -E '^Totals: [0-9]+ passed, [0-9]+ failed, [0-9]+ skipped' | tail -n1)
  if [ -z "$tot" ]; then
    echo "$t: no QtTest Totals line (rc=$rc) -> failed" >&2; printf '%s\n' "$log" | tail -n 20 >&2; F=$((F+1)); continue
  fi
  p=$(echo "$tot" | sed -E 's/^Totals: ([0-9]+) passed, ([0-9]+) failed, ([0-9]+) skipped.*/\1/')
  f=$(echo "$tot" | sed -E 's/^Totals: ([0-9]+) passed, ([0-9]+) failed, ([0-9]+) skipped.*/\2/')
  s=$(echo "$tot" | sed -E 's/^Totals: ([0-9]+) passed, ([0-9]+) failed, ([0-9]+) skipped.*/\3/')
  [ "$rc" -ne 0 ] && [ "$f" -eq 0 ] && f=1
  echo "$t: $tot"
  [ "$f" -gt 0 ] && printf '%s\n' "$log" | grep -E '^FAIL!' -A2 >&2
  P=$((P+p)); F=$((F+f)); S=$((S+s))
done
emit_ctrf "qtest" "$P" "$F" "$S"
