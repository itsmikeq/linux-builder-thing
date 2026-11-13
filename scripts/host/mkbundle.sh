#!/usr/bin/env bash
# PREP HOST: produce the offline bootstrap bundle.
#   output/bundle/busybox          static riscv64 busybox (copied raw; unpacks the tar)
#   output/bundle/rbs-bundle.tar   everything else, rooted at rbs/
#   output/bundle/SHA256SUMS
# The tar is deterministic (sorted, fixed mtime/owner) and uncompressed, so the
# target needs no decompressor and little RAM to unpack it.
. "$(dirname "$0")/common.sh"
SDE=${SOURCE_DATE_EPOCH:-946684800}
BD=$RBS_ROOT/output/bundle; ST=$S0/bundle-stage/rbs
rm -rf "$S0/bundle-stage" "$BD"; mkdir -p "$ST" "$BD"
[ -f "$S0/.done-llvm-bootstrap" ] || die "static toolchain not built (scripts/host/stage0/llvm.sh)"
[ -f "$S0/.done-busybox" ] || die "busybox not built"
python3 "$RBS_ROOT/scripts/host/rbs.py" resolve >/dev/null || die "dependency resolution has errors; run scripts/host/rbs.py resolve"
python3 "$RBS_ROOT/scripts/host/rbs.py" fetch >/dev/null || die "source verification failed"

mkdir -p "$ST/bootstrap/bin" "$ST/sources" "$ST/scripts" "$ST/tests"
cp "$RBS_ROOT/output/bootstrap/bin/busybox" "$ST/bootstrap/bin/busybox"
cp "$RBS_ROOT/output/bootstrap/busybox.config" "$ST/bootstrap/"
cp -a "$TC" "$ST/toolchain"
cp -a "$RBS_ROOT/packages" "$RBS_ROOT/patches" "$ST/"
cp -a "$RBS_ROOT/scripts/target" "$ST/scripts/target"
cp -a "$RBS_ROOT/tests/target" "$ST/tests/target"
cp "$RBS_ROOT/manifest.lock" "$RBS_ROOT/manifest.order" "$ST/"
# every pinned source (each file once), re-verified against manifest.order
grep -v '^#' "$RBS_ROOT/manifest.order" | while read -r st name ver file sum; do
  [ -f "$ST/sources/$file" ] && continue
  echo "$sum  $RBS_ROOT/sources/$file" | sha256sum -c --quiet - || die "checksum $file"
  cp "$RBS_ROOT/sources/$file" "$ST/sources/$file"
done
{
  echo "bundle-format=1"
  echo "created-from-commit=$(git -C "$RBS_ROOT" rev-parse HEAD 2>/dev/null || echo uncommitted)"
  echo "source-date-epoch=$SDE"
  echo "host-compiler=$($HOST_CC --version | head -1)"
  echo "llvm=$LLVM_VER target=$TARGET"
} > "$ST/BUNDLE-INFO"
mkdir -p "$ST"/{build,staging,logs,var,tmp}
tar --sort=name --mtime="@$SDE" --owner=0 --group=0 --numeric-owner --format=gnu \
    -C "$S0/bundle-stage" -cf "$BD/rbs-bundle.tar" rbs
cp "$RBS_ROOT/output/bootstrap/bin/busybox" "$BD/busybox"
( cd "$BD" && sha256sum busybox rbs-bundle.tar > SHA256SUMS )
"$RBS_ROOT/tests/host/check-bundle.sh"
ls -l "$BD"; cat "$BD/SHA256SUMS"
