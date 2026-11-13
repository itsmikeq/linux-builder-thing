#!/usr/bin/env bash
# PREP HOST: complete Stage 0 in dependency order (resumable via build/stage0/.done-*).
#   scripts/host/stage0/all.sh            then: scripts/host/mkbundle.sh
. "$(dirname "$0")/../common.sh"
D=$(dirname "$0")
python3 "$RBS_ROOT/scripts/host/rbs.py" fetch >/dev/null || die "fetch/verify failed"
bash "$D/host-llvm.sh"
# Re-source: HOST_CC now points at the pinned clang.
. "$D/../common.sh"
# Anything previously built by a different host compiler is rebuilt.
want="pinned-clang-$LLVM_VER"
if [ "$(cat "$S0/.compiler" 2>/dev/null)" != "$want" ]; then
  msg "host compiler changed -> rebuilding target objects with $HOST_CC"
  rm -rf "$XRES"
  rm -f "$S0"/.done-{compiler-rt-builtins,musl-cross,llvm-runtimes,llvm-bootstrap,busybox}
  echo "$want" > "$S0/.compiler"
fi
bash "$D/linux-headers.sh"
bash "$D/musl.sh" headers
bash "$D/compiler-rt.sh"
bash "$D/musl.sh"
bash "$D/llvm-runtimes.sh"
bash "$D/busybox.sh"
bash "$D/llvm.sh"
msg "stage 0 complete"
