#!/bin/sh
# RISC-V TARGET: bootstrap orchestrator (POSIX sh, run with the bundled busybox).
#
# First run on the target (after copying `busybox` and `rbs-bundle.tar`):
#     ./busybox tar -xf rbs-bundle.tar        # creates ./rbs
#     ./busybox sh rbs/scripts/target/bootstrap.sh selftest
#     ./busybox sh rbs/scripts/target/bootstrap.sh stage 1
#
# Usage: bootstrap.sh [options] <command>
#   selftest              validate the bootstrap toolchain natively
#   probe-kernel          report kernel/syscall capabilities
#   stage N               build every stage-N package not yet built (resumable)
#   all                   stages 1..2
#   list                  show packages and build state
# Options:
#   --only PKG            build just PKG (always rebuilds)
#   --rebuild PKG         forget PKG's stamp, then build it
#   --from PKG            within the stage, rebuild PKG and everything after it
#   -j N                  parallel jobs (default: min(nproc, mem/1GiB))
# Env: RBS (default: derived from script location), STAGE{1,2,3}_PREFIX, JOBS.
set -eu
case $0 in */*) _d=${0%/*} ;; *) _d=. ;; esac
RBS=${RBS:-$(cd "$_d/../.." && pwd)}
export RBS
BB=$RBS/bootstrap/bin

# Install busybox applet links into the bundle (never into the vendor system).
if [ ! -e "$BB/sh" ]; then
  [ -x "$BB/busybox" ] || { echo "rbs: $BB/busybox missing or not executable" >&2; exit 1; }
  "$BB/busybox" --install -s "$BB"
fi
# Re-exec under the bundled shell with a scrubbed environment (no vendor PATH).
if [ -z "${RBS_HERMETIC:-}" ]; then
  exec "$BB/env" -i RBS="$RBS" RBS_HERMETIC=1 PATH="$BB" JOBS="${JOBS:-}" \
    STAGE1_PREFIX="${STAGE1_PREFIX:-}" STAGE2_PREFIX="${STAGE2_PREFIX:-}" STAGE3_PREFIX="${STAGE3_PREFIX:-}" \
    RUN_CHECKS="${RUN_CHECKS:-}" KEEP_BUILD="${KEEP_BUILD:-}" \
    "$BB/sh" "$RBS/scripts/target/bootstrap.sh" "$@"
fi
for v in STAGE1_PREFIX STAGE2_PREFIX STAGE3_PREFIX JOBS RUN_CHECKS KEEP_BUILD; do
  eval "[ -n \"\${$v:-}\" ] || unset $v"
done
. "$RBS/scripts/target/lib.sh"

auto_jobs() {
  n=$(nproc 2>/dev/null || echo 1)
  memk=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo 2>/dev/null || echo 1048576)
  m=$((memk / 1048576)); [ "$m" -ge 1 ] || m=1
  [ "$m" -lt "$n" ] && n=$m
  echo "$n"
}
[ -n "${JOBS:-}" ] || JOBS=$(auto_jobs)

only= rebuild= from=
while [ $# -gt 0 ]; do
  case $1 in
    --only) only=$2; shift 2 ;;
    --rebuild) rebuild=$2; shift 2 ;;
    --from) from=$2; shift 2 ;;
    -j) JOBS=$2; shift 2 ;;
    -j*) JOBS=${1#-j}; shift ;;
    *) break ;;
  esac
done
export JOBS
cmd=${1:-help}

toolchain_for_stage() { case $1 in 1|2) echo clang ;; *) echo gcc ;; esac; }

build_one() {
  _st=$(order_lookup "$1" | cut -d' ' -f1)
  TOOLCHAIN=$(toolchain_for_stage "$_st") "$BB/sh" "$RBS/scripts/target/build-pkg.sh" "$1"
}

do_stage() {
  # Resumable: packages whose stamp matches "version sha256" are skipped.
  # --from PKG: skip packages before PKG, force-rebuild PKG and all later ones.
  want=$1
  started=; [ -z "$from" ] && started=1
  grep -v '^#' "$RBS/manifest.order" | while read -r st name ver file sum; do
    [ "$st" = "$want" ] || continue
    [ "$name" = "$from" ] && started=1
    [ -n "$started" ] || { msg "$name: skipped (before --from $from)"; continue; }
    if [ -z "$from" ] && [ -f "$VAR/stamps/$name.done" ] && [ "$(cat "$VAR/stamps/$name.done")" = "$ver $sum" ]; then
      msg "$name: up to date"; continue
    fi
    build_one "$name"
  done
}

case $cmd in
  selftest)     exec "$BB/sh" "$RBS/tests/target/selftest.sh" ;;
  probe-kernel) exec "$BB/sh" "$RBS/tests/target/probe-kernel.sh" ;;
  list)
    grep -v '^#' "$RBS/manifest.order" | while read -r st name ver file sum; do
      s=pending; [ -f "$VAR/stamps/$name.done" ] && s=built
      [ "$st" = 0 ] && s=prep-host
      printf '%s %-22s %-10s %s\n' "stage$st" "$name" "$ver" "$s"
    done ;;
  stage)
    [ -n "${2:-}" ] || die "usage: bootstrap.sh stage N"
    [ -n "$rebuild" ] && rm -f "$VAR/stamps/$rebuild.done"
    if [ -n "$only" ]; then build_one "$only"; else do_stage "$2"; fi
    msg "stage $2 complete" ;;
  all)
    for s in 1 2; do "$BB/sh" "$RBS/scripts/target/bootstrap.sh" stage $s; done ;;
  build)  # build a single package: bootstrap.sh build PKG
    build_one "${2:?usage: bootstrap.sh build PKG}" ;;
  *)
    if [ -n "$only" ]; then build_one "$only"; exit; fi
    if [ -n "$rebuild" ]; then rm -f "$VAR/stamps/$rebuild.done"; build_one "$rebuild"; exit; fi
    sed -n '2,25p' "$RBS/scripts/target/bootstrap.sh"; exit 1 ;;
esac
