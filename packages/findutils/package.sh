pkg_name=findutils
pkg_version=4.10.0
pkg_stage=1
pkg_source_url="https://ftp.gnu.org/gnu/findutils/findutils-${pkg_version}.tar.xz"
pkg_sig_url="${pkg_source_url}.sig"
pkg_verify="gpg-detached:gnu-keyring.gpg"
pkg_sha256=1387e0b67ff247d2abde998f90dfbf70c1491391a59ddfecb8ae698789f0a4f5
pkg_build_tools="sh cc make sed grep awk ar ranlib install diff cmp xargs"
pkg_build_deps="llvm-bootstrap"
pkg_runtime_deps=""
pkg_provides="find xargs"
pkg_outputs="bin/find bin/xargs"
pkg_configure_opts="--disable-nls --without-selinux"
pkg_validate() { "$DESTDIR$PREFIX/bin/find" "$DESTDIR$PREFIX/bin" -name find | grep -q find; }
# Not needed: generated files ship in the release tarball / used only by tests or optional features.
pkg_optional_tools="python3"
