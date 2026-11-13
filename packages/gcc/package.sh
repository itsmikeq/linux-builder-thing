pkg_name=gcc
pkg_version=15.2.0
pkg_stage=2
pkg_source_url="https://ftp.gnu.org/gnu/gcc/gcc-${pkg_version}/gcc-${pkg_version}.tar.xz"
pkg_sig_url="${pkg_source_url}.sig"
pkg_verify="gpg-detached:gnu-keyring.gpg"
pkg_sha256=438fd996826b0c82485a29da03a72d71d6e3541a83ec702df4271f6fe025d24e
pkg_build_tools="sh cc c++ make sed grep awk m4 bison flex as ld ar ranlib nm strip install diff cmp xargs"
pkg_build_deps="llvm-bootstrap musl linux-uapi gmp mpfr mpc binutils"
pkg_provides="gcc g++ cpp cc c++ gcov"
pkg_runtime_deps="binutils"
pkg_outputs="bin/gcc bin/g++"
pkg_optional_tools="makeinfo perl python3 autogen guile expect runtest gnat gdc lex"
# Stage 2: one-pass native GCC compiled by the bootstrap clang (no 3-stage bootstrap
# yet; that is gcc-final in stage 3). The sysroot lives inside the prefix, so the
# installed GCC is relocatable. --with-specs makes every link static (no musl
# dynamic loader on the vendor OS; see docs/DESIGN.md).
pkg_configure_opts="--target=$TRIPLE --disable-bootstrap --enable-languages=c,c++ --disable-multilib
 --disable-nls --disable-werror --disable-shared --enable-static --disable-lto --disable-plugin
 --disable-libsanitizer --disable-libgomp --disable-libssp --disable-libvtv --disable-libquadmath
 --disable-libitm --disable-libatomic-ifuncs --disable-libstdcxx-pch --disable-gnu-indirect-function
 --enable-threads=posix --enable-tls --enable-__cxa_atexit --enable-clocale=generic
 --with-arch=rv64gc --with-abi=lp64d --with-sysroot=$SYSROOT --with-native-system-header-dir=/usr/include
 --with-as=$PREFIX/bin/as --with-ld=$PREFIX/bin/ld.bfd
 --with-gmp=$PREFIX --with-mpfr=$PREFIX --with-mpc=$PREFIX --without-zstd --with-system-zlib=no"
pkg_build() { make SHELL="$CONFIG_SHELL" -j"$JOBS" MAKEINFO=true; }
pkg_install() { make SHELL="$CONFIG_SHELL" DESTDIR="$DESTDIR" MAKEINFO=true install-strip; ln -sf gcc "$DESTDIR$PREFIX/bin/cc"; ln -sf g++ "$DESTDIR$PREFIX/bin/c++"; }
pkg_configure() {
  env CFLAGS="-O2" CXXFLAGS="-O2" LDFLAGS="-static" "$CONFIG_SHELL" "$SRC/configure" --prefix="$PREFIX" \
    --build="$TRIPLE" --host="$TRIPLE" $pkg_configure_opts \
    --with-specs='%{!shared:%{!static-pie:-static}}'
}
pkg_validate() {
  t=$TMPDIR/gcc-validate; rm -rf "$t"; mkdir -p "$t"; cd "$t"
  printf '#include <stdio.h>\nint main(void){puts("gcc-ok");return 0;}\n' > a.c
  printf '#include <iostream>\n#include <stdexcept>\nint main(){try{throw std::runtime_error("x");}catch(std::exception&e){std::cout<<"g++-ok\\n";}}\n' > b.cc
  G=$DESTDIR$PREFIX/bin
  # Run from staging (not yet merged): libexec/headers resolve relative to the driver,
  # but the sysroot (musl, already in $PREFIX) must be given explicitly here.
  "$G/gcc" --sysroot="$SYSROOT" -O2 a.c -o a && [ "$(./a)" = gcc-ok ]
  "$G/g++" --sysroot="$SYSROOT" -O2 b.cc -o b && [ "$(./b)" = g++-ok ]
  is_static_riscv a && is_static_riscv b
}
