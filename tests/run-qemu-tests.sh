#!/usr/bin/env bash
# PREP HOST: end-to-end tests in QEMU riscv64 'virt' (TCG; no network; simulated vendor OS).
#   tests/run-qemu-tests.sh <level> [extra bootstrap.sh args]
# levels: smoke   selftest + kernel probe (+ bundle offline/no-vendor-tool checks)
#         stage1 | stage2 | stage3 | stage4   build that stage natively (resumable)
#         pkg:<name>                          build a single package
# Env: RESUME=1 reuse the existing work image (keeps built packages)
#      QEMU_SMP, QEMU_MEM, JOBS, WORK_IMG (default output/qemu/work.img), DISK_SIZE
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/scripts/host/common.sh"
level=${1:?usage: run-qemu-tests.sh smoke|stage1|stage2|stage3|stage4|pkg:NAME}; shift || true
IMG=${WORK_IMG:-$ROOT/output/qemu/work.img}
R=$S0/run.sh
"$ROOT/tests/host/check-bundle.sh" >/dev/null
case $level in
  smoke) steps="selftest probe-kernel" ;;
  stage[1-4]) steps="selftest stage ${level#stage}" ;;
  pkg:*) steps="build ${level#pkg:}" ;;
  *) die "unknown level $level" ;;
esac
cat > "$R" <<RUN
# Operator commands on the (simulated) vendor device. PATH is empty: only the
# transferred ./busybox and the bundle are used.
set -e
cd /work
if [ ! -d rbs ]; then echo "rbs: unpacking bundle"; ./busybox tar -xf rbs-bundle.tar; fi
export JOBS=${JOBS:-}
./busybox sh rbs/scripts/target/bootstrap.sh $* $steps
if [ -s /work/.vendor-sh-audit ]; then
  echo "FAIL: the vendor /bin/sh was used by the bootstrap:"; ./busybox head -20 /work/.vendor-sh-audit; exit 1
fi
echo "PASS: vendor /bin/sh never used; no vendor tools on PATH"
RUN
if [ -n "${RESUME:-}" ] && [ -f "$IMG" ]; then
  debugfs -w -R "rm /run.sh" "$IMG" >/dev/null 2>&1 || true
  debugfs -w -R "write $R /run.sh" "$IMG" >/dev/null
  msg "resuming with existing $IMG"
else
  "$ROOT/scripts/host/qemu/mkworkdisk.sh" "$IMG" "$R" "${DISK_SIZE:-24G}" >/dev/null
fi
set +e
QEMU_LOG=$ROOT/logs/qemu-$level.log "$ROOT/scripts/host/qemu/run.sh" "$IMG"
rc=$?
set -e
rm -rf "$ROOT/logs/target"; mkdir -p "$ROOT/logs/target"
"$ROOT/scripts/host/qemu/getfile.sh" "$IMG" /rbs/logs "$ROOT/logs/target" || true
"$ROOT/scripts/host/qemu/getfile.sh" "$IMG" /rbs/var "$ROOT/logs/target" || true
"$ROOT/scripts/host/qemu/getfile.sh" "$IMG" /run.log "$ROOT/logs/target" 2>/dev/null || true
[ $rc = 0 ] && msg "TEST $level: PASS" || msg "TEST $level: FAIL (rc=$rc); logs in logs/target and logs/qemu-$level.log"
exit $rc
