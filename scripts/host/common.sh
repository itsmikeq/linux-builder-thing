# Common environment for PREPARATION-HOST stage 0 scripts (bash).
# Nothing here runs on the RISC-V target.
set -euo pipefail
RBS_ROOT=${RBS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}
TARGET=riscv64-unknown-linux-musl
ARCHFLAGS="-march=rv64gc -mabi=lp64d"
JOBS=${JOBS:-$(nproc)}
LLVM_VER=21.1.8
LLVM_MAJOR=${LLVM_VER%%.*}

# Host compiler used for cross compilation (recorded in provenance).
# Stage 0a builds a pinned clang $LLVM_VER into build/stage0/host-llvm; once it
# exists every cross step uses it. The distro clang is only used to build it.
HL=$RBS_ROOT/build/stage0/host-llvm/bin
if [ -x "$HL/clang" ]; then
  HOST_CC=$HL/clang HOST_CXX=$HL/clang++ HOST_AR=$HL/llvm-ar HOST_RANLIB=$HL/llvm-ranlib HOST_NM=$HL/llvm-nm
  export PATH=$HL:$PATH   # so -fuse-ld=lld finds the pinned ld.lld
else
  HOST_CC=${HOST_CC:-clang-18} HOST_CXX=${HOST_CXX:-clang++-18}
  HOST_AR=${HOST_AR:-llvm-ar-18} HOST_RANLIB=${HOST_RANLIB:-llvm-ranlib-18} HOST_NM=${HOST_NM:-llvm-nm-18}
fi

S0=$RBS_ROOT/build/stage0           # stage0 scratch (extracted sources, build trees)
TC=$RBS_ROOT/output/toolchain       # FINAL relocatable RISC-V toolchain (static)
SYSROOT=$TC/sysroot                 # musl + linux headers + libc++ for riscv64
XRES=$S0/xresource                  # resource dir for the *host* clang when targeting riscv64
LOGDIR=$RBS_ROOT/logs/stage0
mkdir -p "$S0" "$TC" "$SYSROOT/usr/include" "$SYSROOT/usr/lib" "$LOGDIR"

# Cross flags for the host clang. -resource-dir points at a private copy of the
# host clang headers plus OUR riscv64 compiler-rt, so the host install is untouched.
XCFLAGS="--target=$TARGET $ARCHFLAGS --sysroot=$SYSROOT -resource-dir=$XRES"
XLDFLAGS="-fuse-ld=lld --rtlib=compiler-rt --unwindlib=none"   # C only; C++ links add libunwind explicitly

die() { echo "error: $*" >&2; exit 1; }
msg() { echo "==> [$(date +%H:%M:%S)] $*"; }

# srcdir <pkg>: verify checksum (via rbs.py fetch) and extract once into build/stage0/src
srcdir() {
  local pkg=$1 file dir
  python3 "$RBS_ROOT/scripts/host/rbs.py" fetch "$pkg" >/dev/null || die "source verification failed for $pkg"
  file=$(sed -n 's/^pkg_source_url="\(.*\)"/\1/p' "$RBS_ROOT/packages/$pkg/package.sh")
  local ver=$(sed -n 's/^pkg_version=//p' "$RBS_ROOT/packages/$pkg/package.sh")
  file=$(basename "${file//\$\{pkg_version\}/$ver}")
  dir=$S0/src/${file%.tar.*}
  if [ ! -f "$dir/.rbs-extracted" ]; then
    rm -rf "$dir"; mkdir -p "$S0/src"
    tar -xf "$RBS_ROOT/sources/$file" -C "$S0/src" --no-same-owner
    [ -d "$dir" ] || die "expected $dir after extracting $file"
    for p in "$RBS_ROOT"/patches/"$pkg"/*.patch; do
      [ -e "$p" ] || continue
      msg "patch $(basename "$p")"; patch -d "$dir" -p1 < "$p"
    done
    touch "$dir/.rbs-extracted"
  fi
  echo "$dir"
}

stamp()   { touch "$S0/.done-$1"; }
done_p()  { [ -f "$S0/.done-$1" ] && [ -z "${FORCE:-}" ]; }

# Make the private host resource dir: host clang headers + (later) riscv64 builtins
setup_xres() {
  if [ ! -d "$XRES/include" ]; then
    local hres; hres=$($HOST_CC -print-resource-dir)
    mkdir -p "$XRES"; cp -a "$hres/include" "$XRES/include"
  fi
}
