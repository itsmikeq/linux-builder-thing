# RISC-V TARGET-SIDE library (POSIX sh; runs under the bundled busybox ash).
# Sourced by bootstrap.sh and build-pkg.sh. Never sourced on the prep host.
#
# Directory layout under $RBS (all separate, all configurable):
#   sources/   pristine verified tarballs (read-only after transfer)
#   packages/  metadata (package.sh)            patches/  per-package patches
#   build/     per-package extraction + build trees (disposable)
#   staging/   per-package DESTDIR install trees (disposable)
#   logs/      per-package logs (kept)
#   var/       stamps, installed-file lists, provenance records
#   bootstrap/ busybox + applet links      toolchain/ static clang/lld + sysroot
#   tools/     stage1 prefix   gcc-boot/ stage2 prefix   native/ stage3 prefix

: "${RBS:?RBS must point at the bundle root}"
TRIPLE=riscv64-unknown-linux-musl
JOBS=${JOBS:-2}
BB=$RBS/bootstrap/bin
TC=$RBS/toolchain
STAGE1_PREFIX=${STAGE1_PREFIX:-$RBS/tools}
STAGE2_PREFIX=${STAGE2_PREFIX:-$RBS/gcc-boot}
STAGE3_PREFIX=${STAGE3_PREFIX:-$RBS/native}
SRCDIR=$RBS/sources BUILDROOT=$RBS/build STAGEROOT=$RBS/staging LOGDIR=$RBS/logs VAR=$RBS/var

die() { echo "rbs: error: $*" >&2; exit 1; }
msg() { echo "rbs: [$(date +%H:%M:%S)] $*"; }

prefix_for_stage() {
  case $1 in
    1) echo "$STAGE1_PREFIX" ;; 2) echo "$STAGE2_PREFIX" ;; 3|4) echo "$STAGE3_PREFIX" ;;
    *) die "no target prefix for stage $1 (stage 0 is built on the prep host)" ;;
  esac
}

# Hermetic environment. Only bundle-provided directories are on PATH; nothing
# from the vendor OS (/bin, /usr/bin, ...) is reachable by name.
# TOOLCHAIN=clang (stages 1-2) or gcc (stage 3+).
rbs_env() {
  _tc=${1:-clang}
  _p="$STAGE1_PREFIX/bin:$BB"
  case $_tc in
    clang)
      _p="$STAGE1_PREFIX/bin:$STAGE2_PREFIX/bin:$TC/bin:$BB"
      CC=clang CXX=clang++ CPP="clang -E" AR=llvm-ar RANLIB=llvm-ranlib NM=llvm-nm
      STRIP=llvm-strip OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf LD=ld.lld
      CFLAGS="-O2" CXXFLAGS="-O2" LDFLAGS="-static" ;;
    gcc)
      _gp=${GCC_PREFIX:-$STAGE2_PREFIX}
      _p="$STAGE3_PREFIX/bin:$_gp/bin:$STAGE1_PREFIX/bin:$BB"
      CC=gcc CXX=g++ CPP="gcc -E" AR=ar RANLIB=ranlib NM=nm STRIP=strip OBJCOPY=objcopy
      OBJDUMP=objdump READELF=readelf LD=ld
      CFLAGS="-O2" CXXFLAGS="-O2" LDFLAGS="-static" ;;
    *) die "unknown toolchain $_tc" ;;
  esac
  PATH=$_p
  CONFIG_SHELL=$BB/sh SHELL=$BB/sh
  TMPDIR=$RBS/tmp HOME=$RBS/tmp
  LC_ALL=C LANG=C TZ=UTC
  # Reproducibility: fixed timestamps for tools that honour it.
  SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-946684800}
  export PATH CONFIG_SHELL SHELL TMPDIR HOME LC_ALL LANG TZ SOURCE_DATE_EPOCH
  export CC CXX CPP AR RANLIB NM STRIP OBJCOPY OBJDUMP READELF LD CFLAGS CXXFLAGS LDFLAGS
  unset CPATH C_INCLUDE_PATH LIBRARY_PATH LD_LIBRARY_PATH PKG_CONFIG_PATH MAKEFLAGS MFLAGS
  mkdir -p "$TMPDIR"
}

# order_lookup <pkg> -> "stage name version file sha256" from manifest.order
order_lookup() {
  _l=$(grep -v '^#' "$RBS/manifest.order" | awk -v p="$1" '$2==p')
  [ -n "$_l" ] || die "package '$1' not in manifest.order"
  echo "$_l"
}

# require_tools: actionable error when a declared build tool is not reachable.
require_tools() {
  _missing=
  for _t in "$@"; do
    command -v "$_t" >/dev/null 2>&1 || _missing="$_missing $_t"
  done
  [ -z "$_missing" ] || die "missing build tool(s):$_missing (PATH=$PATH). Build the providing package first; see manifest.lock 'edges'."
}

# is_static_riscv <file>: ELF, machine RISC-V, no PT_INTERP, no DT_NEEDED
is_static_riscv() {
  _rd=$(command -v llvm-readelf || command -v readelf) || return 2
  "$_rd" -h "$1" 2>/dev/null | grep -q 'RISC-V' || return 1
  "$_rd" -l "$1" 2>/dev/null | grep -q 'INTERP' && return 1
  "$_rd" -d "$1" 2>/dev/null | grep -q 'NEEDED' && return 1
  return 0
}
