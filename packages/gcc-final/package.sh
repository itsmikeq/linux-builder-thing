# Stage 3: GCC rebuilt BY GCC (stage-2 gcc), using GCC's own 3-stage
# 'make bootstrap' (stage1 built by the stage-2 gcc, stage2 by stage1,
# stage3 by stage2, then 'compare' of stage2 vs stage3 objects). GMP/MPFR/MPC are
# built in-tree so they too are compiled by GCC at every stage. No clang anywhere:
# PATH for this stage does not contain the bootstrap toolchain (see lib.sh).
pkg_name=gcc-final
pkg_version=15.2.0
pkg_stage=3
pkg_toolchain=gcc   # stage 3+: built by GCC only; resolver forbids clang/LLVM providers
pkg_source_url="https://ftp.gnu.org/gnu/gcc/gcc-${pkg_version}/gcc-${pkg_version}.tar.xz"
pkg_sig_url="${pkg_source_url}.sig"
pkg_verify="gpg-detached:gnu-keyring.gpg"
pkg_sha256=438fd996826b0c82485a29da03a72d71d6e3541a83ec702df4271f6fe025d24e
pkg_build_tools="sh cc c++ make sed grep awk m4 bison flex as ld ar ranlib nm strip install diff cmp xargs tar xz"
pkg_build_deps="gcc binutils-final musl-final linux-uapi-final"
pkg_extra_sources="gmp-6.3.0.tar.xz mpfr-4.2.2.tar.xz mpc-1.3.1.tar.gz"
pkg_optional_tools="makeinfo perl python3 autogen guile expect runtest lex"
pkg_outputs="bin/gcc bin/g++"
pkg_prepare() {
  for t in $pkg_extra_sources; do
    want=$(grep -v '^#' "$RBS/manifest.order" | awk -v f="$t" '$4==f{print $5; exit}')
    [ -n "$want" ] && [ "$(sha256sum "$SRCDIR/$t" | cut -d' ' -f1)" = "$want" ] || die "extra source $t failed verification"
    tar -xf "$SRCDIR/$t" -C "$SRC"
    d=${t%.tar.*}; mv "$SRC/$d" "$SRC/${d%-*}"
  done
}
pkg_configure() {
  env CFLAGS="-O2" CXXFLAGS="-O2" LDFLAGS="-static" "$CONFIG_SHELL" "$SRC/configure" --prefix="$PREFIX" \
    --build="$TRIPLE" --host="$TRIPLE" --target="$TRIPLE" \
    --enable-bootstrap --enable-languages=c,c++ --disable-multilib --disable-nls --disable-werror \
    --disable-shared --enable-static --disable-lto --disable-plugin --disable-libsanitizer \
    --disable-libgomp --disable-libssp --disable-libvtv --disable-libquadmath --disable-libitm \
    --disable-libstdcxx-pch --disable-gnu-indirect-function --enable-threads=posix --enable-tls \
    --enable-__cxa_atexit --enable-clocale=generic --with-arch=rv64gc --with-abi=lp64d \
    --with-sysroot="$SYSROOT" --with-native-system-header-dir=/usr/include \
    --with-as="$PREFIX/bin/as" --with-ld="$PREFIX/bin/ld.bfd" --without-zstd --with-system-zlib=no \
    --with-specs='%{!shared:%{!static-pie:-static}}'
}
pkg_build() { make SHELL="$CONFIG_SHELL" -j"$JOBS" MAKEINFO=true BOOT_CFLAGS="-O2" bootstrap; }
pkg_install() { make SHELL="$CONFIG_SHELL" DESTDIR="$DESTDIR" MAKEINFO=true install-strip; ln -sf gcc "$DESTDIR$PREFIX/bin/cc"; ln -sf g++ "$DESTDIR$PREFIX/bin/c++"; }
pkg_validate() {
  # 'make bootstrap' already ran 'compare'; confirm it did and nothing differed.
  grep -q 'Comparing stages 2 and 3' "$LOG" || { echo "no stage2/3 comparison ran"; return 1; }
  ! grep -q 'Bootstrap comparison failure' "$LOG"
  "$DESTDIR$PREFIX/bin/gcc" -v 2>&1 | tail -1
  "$DESTDIR$PREFIX/bin/gcc" -dumpspecs >/dev/null
  # No clang/LLVM fingerprints in the final compiler's .comment section
  ! "$PREFIX/bin/readelf" -p .comment "$DESTDIR$PREFIX/libexec/gcc/$TRIPLE/$pkg_version/cc1" 2>/dev/null | grep -qi clang
}
