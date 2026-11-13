pkg_name=binutils-final
pkg_version=2.45
pkg_stage=3
pkg_toolchain=gcc   # stage 3+: built by GCC only; resolver forbids clang/LLVM providers
pkg_source_url="https://ftp.gnu.org/gnu/binutils/binutils-${pkg_version}.tar.xz"
pkg_sig_url="${pkg_source_url}.sig"
pkg_verify="gpg-detached:gnu-keyring.gpg"
pkg_sha256=c50c0e7f9cb188980e2cc97e4537626b1672441815587f1eab69d2a1bfbef5d2
pkg_build_tools="sh cc make sed grep awk bison flex m4 ar ranlib install diff cmp xargs"
pkg_build_deps="gcc linux-uapi-final"
pkg_runtime_deps=""
pkg_provides=""   # final copies; stage2 binutils remains the provider for the graph
pkg_outputs="bin/as bin/ld.bfd bin/ar"
# gold/gprofng need C++/extra deps and are not required for GCC.
pkg_configure_opts="--disable-nls --disable-werror --disable-shared --enable-static --disable-gprofng --disable-gold --disable-gdb --disable-gdbserver --disable-sim --disable-libdecnumber --disable-readline --without-zstd --without-debuginfod --with-system-zlib=no --enable-deterministic-archives --with-sysroot=$SYSROOT --enable-64-bit-bfd"
pkg_optional_tools="makeinfo texi2dvi perl expect runtest lex yacc"
pkg_build() { make SHELL="$CONFIG_SHELL" -j"$JOBS" MAKEINFO=true; }
pkg_install() { make SHELL="$CONFIG_SHELL" DESTDIR="$DESTDIR" MAKEINFO=true install; }
pkg_validate() { "$DESTDIR$PREFIX/bin/as" --version | head -1 | grep -q 'GNU assembler'; }
