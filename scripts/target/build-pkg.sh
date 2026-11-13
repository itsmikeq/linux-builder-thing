#!/bin/sh
# RISC-V TARGET: build ONE package natively.
#   build-pkg.sh <pkg>
# Env: RBS (bundle root), JOBS, TOOLCHAIN (clang|gcc), KEEP_BUILD=1 to keep trees.
# Phases: verify -> extract -> patch -> configure -> build -> install(DESTDIR)
#         -> validate -> check outputs are static RISC-V -> merge into prefix -> stamp
set -eu
RBS=${RBS:?}
. "$RBS/scripts/target/lib.sh"
pkg=${1:?usage: build-pkg.sh <pkg>}
set -- $(order_lookup "$pkg")
stage=$1 version=$3 file=$4 sum=$5
PREFIX=$(prefix_for_stage "$stage")
SRC_ROOT=$BUILDROOT/$pkg
DESTDIR=$STAGEROOT/$pkg
LOG=$LOGDIR/$pkg.log
mkdir -p "$LOGDIR" "$VAR/stamps" "$VAR/files" "$VAR/provenance"
export PREFIX DESTDIR JOBS TRIPLE
# Paths GCC needs (stage >= 2): a sysroot inside the prefix keeps GCC relocatable.
SYSROOT=$PREFIX/sysroot
SYSROOT_REL=$SYSROOT
export SYSROOT SYSROOT_REL

# ---- default (autotools) phase implementations; package.sh may override ----
pkg_configure_opts= pkg_configure_env= pkg_in_tree= pkg_outputs= pkg_build_tools= pkg_check_cmd=
pkg_configure() {
  env $pkg_configure_env "$CONFIG_SHELL" "$SRC/configure" \
    --prefix="$PREFIX" --build="$TRIPLE" --host="$TRIPLE" $pkg_configure_opts
}
pkg_build()    { make SHELL="$CONFIG_SHELL" -j"$JOBS"; }
pkg_install()  { make SHELL="$CONFIG_SHELL" DESTDIR="$DESTDIR" install; }
pkg_validate() { :; }
pkg_prepare()  { :; }

rbs_env "${TOOLCHAIN:-clang}"
. "$RBS/packages/$pkg/package.sh"

{
  echo "### package $pkg $version stage $stage  $(date -u)"
  echo "### PREFIX=$PREFIX JOBS=$JOBS TOOLCHAIN=${TOOLCHAIN:-clang}"
  echo "### PATH=$PATH"
  echo "### uname: $(uname -a)"
} > "$LOG"
run() { # run <phase> <cmd...> : log, and fail with an actionable message
  msg "$pkg: $1"; _ph=$1; shift
  echo "### phase $_ph" >> "$LOG"
  if ! ( "$@" ) >> "$LOG" 2>&1; then
    echo "rbs: $pkg failed in phase '$_ph'. Last log lines:" >&2
    tail -n 25 "$LOG" >&2
    die "$pkg: phase $_ph failed; full log: $LOG ; rerun: $RBS/scripts/target/bootstrap.sh --only $pkg"
  fi
}

# Declared build tools must exist (cycle-broken tools are allowed to be absent).
_need=
for t in $pkg_build_tools; do
  case " ${pkg_cycle_break:-} " in *" $t "*) continue ;; esac
  _need="$_need $t"
done
require_tools $_need

verify() {
  f=$SRCDIR/$file
  [ -f "$f" ] || die "source $f missing from bundle"
  got=$(sha256sum "$f" | cut -d' ' -f1)
  [ "$got" = "$sum" ] || die "CHECKSUM MISMATCH for $f: $got != $sum"
}
extract() {
  rm -rf "$SRC_ROOT" "$DESTDIR"; mkdir -p "$SRC_ROOT/src" "$DESTDIR"
  tar -xf "$SRCDIR/$file" -C "$SRC_ROOT/src"
  set -- "$SRC_ROOT"/src/*
  [ $# -eq 1 ] && [ -d "$1" ] || die "unexpected tarball layout for $file"
  mv "$1" "$SRC_ROOT/s"; rmdir "$SRC_ROOT/src"
}
apply_patches() {
  for p in "$RBS/patches/$pkg"/*.patch; do
    [ -e "$p" ] || continue
    # busybox patch has no -d: apply from inside the tree
    echo "applying $p"; ( cd "$SRC" && patch -p1 -i "$p" ) || return 1
  done
}
# Hermeticity: scripts run by path (build-aux/install-sh, git-version-gen, ...) would
# make the kernel use the VENDOR /bin/sh via their '#!/bin/sh' line. Point them at the
# bundled shell instead. mtimes are preserved so make never sees "changed" sources.
fix_shebangs() {
  n=0
  grep -rlE '^#! ?(/bin/sh|/usr/bin/env sh)' "$SRC" 2>/dev/null | while IFS= read -r f; do
    IFS= read -r first < "$f" || continue
    case $first in
      '#!/bin/sh'*|'#! /bin/sh'*|'#!/usr/bin/env sh'*|'#! /usr/bin/env sh'*) ;;
      *) continue ;;
    esac
    touch -r "$f" "$f.rbs-mtime"
    sed -i -e "1s|^#! \{0,1\}/usr/bin/env sh|#!$BB/sh|" -e "1s|^#! \{0,1\}/bin/sh|#!$BB/sh|" "$f"
    touch -r "$f.rbs-mtime" "$f"; rm -f "$f.rbs-mtime"
    n=$((n+1)); echo "shebang -> $BB/sh: ${f#$SRC/}"
  done
  # Report other interpreters (not rewritten): they must be provided by a package.
  grep -rlE '^#! ?/(usr/)?bin/(env )?(perl|python|bash)' "$SRC" 2>/dev/null | head -20 | sed 's/^/note: other interpreter: /' || true
}
check_outputs() {
  rc=0
  for o in $pkg_outputs; do
    f=$DESTDIR$PREFIX/$o
    [ -e "$f" ] || { echo "MISSING expected output $o"; rc=1; continue; }
    case $o in
      bin/*) if is_static_riscv "$f"; then echo "ok static riscv: $o"; else echo "NOT a static RISC-V executable: $o"; rc=1; fi ;;
      *) echo "ok: $o" ;;
    esac
  done
  return $rc
}
merge() {
  # Record the file list (for clean rebuilds), then copy into the prefix.
  ( cd "$DESTDIR$PREFIX" && find . ! -type d ) | sort > "$VAR/files/$pkg.files"
  mkdir -p "$PREFIX"
  ( cd "$DESTDIR$PREFIX" && tar -cf - . ) | ( cd "$PREFIX" && tar -xf - )
}
uninstall_old() {
  [ -f "$VAR/files/$pkg.files" ] || return 0
  while IFS= read -r f; do rm -f "$PREFIX/$f"; done < "$VAR/files/$pkg.files"
}

run verify verify
run extract extract
SRC=$SRC_ROOT/s
if [ -n "$pkg_in_tree" ]; then B=$SRC; else B=$SRC_ROOT/b; mkdir -p "$B"; fi
export SRC B
run patch apply_patches
run shebangs fix_shebangs
cd "$SRC"; run prepare pkg_prepare
cd "$B"
run configure pkg_configure
run build pkg_build
[ -n "${RUN_CHECKS:-}" ] && [ -n "$pkg_check_cmd" ] && run check sh -c "$pkg_check_cmd"
run install pkg_install
run validate pkg_validate
run outputs check_outputs
run uninstall-old uninstall_old
run merge merge
{
  echo "package=$pkg"; echo "version=$version"; echo "source=$file"; echo "sha256=$sum"
  echo "toolchain=${TOOLCHAIN:-clang}"; echo "cc=$($CC --version 2>&1 | head -1)"
  echo "kernel=$(uname -srm)"; echo "date=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "files=$(wc -l < "$VAR/files/$pkg.files")"
} > "$VAR/provenance/$pkg"
echo "$version $sum" > "$VAR/stamps/$pkg.done"
[ -n "${KEEP_BUILD:-}" ] || rm -rf "$SRC_ROOT" "$DESTDIR"
msg "$pkg: done"
