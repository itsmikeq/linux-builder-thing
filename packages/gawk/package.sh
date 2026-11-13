pkg_name=gawk
pkg_version=5.3.2
pkg_stage=1
pkg_source_url="https://ftp.gnu.org/gnu/gawk/gawk-${pkg_version}.tar.xz"
pkg_sig_url="${pkg_source_url}.sig"
pkg_verify="gpg-detached:gnu-keyring.gpg"
pkg_sha256=f8c3486509de705192138b00ef2c00bbbdd0e84c30d5c07d23fc73a9dc4cc9cc
pkg_build_tools="sh cc make sed grep awk ar ranlib install diff cmp xargs"
pkg_build_deps="llvm-bootstrap"
pkg_runtime_deps=""
pkg_provides="gawk awk"
pkg_outputs="bin/gawk"
pkg_configure_opts="--disable-nls --disable-extensions --disable-mpfr --without-readline"
pkg_install() { make SHELL="$CONFIG_SHELL" DESTDIR="$DESTDIR" install; ln -sf gawk "$DESTDIR$PREFIX/bin/awk"; }
pkg_validate() { [ "$(echo 2 3 | "$DESTDIR$PREFIX/bin/gawk" '{print $1*$2}')" = 6 ]; }
# Not needed: generated files ship in the release tarball / used only by tests or optional features.
pkg_optional_tools="yacc"
