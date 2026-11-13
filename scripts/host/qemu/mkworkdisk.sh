#!/usr/bin/env bash
# PREP HOST: create the work disk = what an operator would copy to the device:
#   busybox (static, executable) + rbs-bundle.tar + run.sh (the operator's commands).
#   mkworkdisk.sh <img> <run.sh> [size]
. "$(dirname "$0")/../common.sh"
IMG=${1:?} RUN=${2:?} SIZE=${3:-20G}
BD=$RBS_ROOT/output/bundle
[ -f "$BD/rbs-bundle.tar" ] || die "no bundle; run scripts/host/mkbundle.sh"
D=$S0/workdisk; rm -rf "$D"; mkdir -p "$D"
cp "$BD/busybox" "$D/busybox"; chmod 755 "$D/busybox"
ln "$BD/rbs-bundle.tar" "$D/rbs-bundle.tar" 2>/dev/null || cp "$BD/rbs-bundle.tar" "$D/"
cp "$RUN" "$D/run.sh"
rm -f "$IMG"
mke2fs -q -t ext4 -E root_owner=0:0 -L rbswork -d "$D" "$IMG" "$SIZE"
ls -ls "$IMG"
