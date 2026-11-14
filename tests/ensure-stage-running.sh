#!/usr/bin/env bash
# PREP HOST: keep a long QEMU stage run going across host/container restarts.
#   tests/ensure-stage-running.sh <level> [extra args]
# - QEMU running            -> report progress
# - finished (TEST line)    -> report the result
# - neither (killed)        -> resume with RESUME=1 (stamped packages are skipped;
#                              the work disk keeps stamps and the cumulative audit)
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
level=${1:?level}; shift
LOG=$ROOT/logs/${level}.driver.log
last() { sed 's/\r$//' "$LOG" 2>/dev/null | grep -a -E ': done$|failed|FAIL|PASS|TEST' | tail -${1:-3}; }
if pgrep -f "qemu-system-riscv64.*$(basename "${WORK_IMG:-work.img}")" >/dev/null; then
  echo "RUNNING: $(sed 's/\r$//' "$LOG" | grep -a 'rbs:' | tail -1)"; exit 0
fi
if grep -q "TEST $level:" "$LOG" 2>/dev/null; then
  echo "FINISHED:"; last 40; exit 0
fi
echo "NOT RUNNING (interrupted?) -> resuming $level"
[ -f "$LOG" ] && cp "$LOG" "$LOG.$(date +%s)"
( RESUME=1 nohup bash "$ROOT/tests/run-qemu-tests.sh" "$level" "$@" > "$LOG" 2>&1 & )
echo "resumed"
