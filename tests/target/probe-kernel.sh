#!/bin/sh
# RISC-V TARGET: build and run the kernel capability probe with the bootstrap clang.
set -eu
RBS=${RBS:?}
. "$RBS/scripts/target/lib.sh"
rbs_env clang
mkdir -p "$RBS/tmp" "$LOGDIR"
clang -O1 "$RBS/tests/target/probe-kernel.c" -o "$RBS/tmp/probe-kernel"
"$RBS/tmp/probe-kernel" | tee "$LOGDIR/kernel-probe.txt"
