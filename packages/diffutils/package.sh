pkg_name=diffutils
pkg_version=3.10
pkg_stage=1
pkg_source_url="https://ftp.gnu.org/gnu/diffutils/diffutils-${pkg_version}.tar.xz"
pkg_sig_url="${pkg_source_url}.sig"
pkg_verify="gpg-detached:gnu-keyring.gpg"
pkg_sha256=90e5e93cc724e4ebe12ede80df1634063c7a855692685919bfe60b556c9bd09e
pkg_build_tools="sh cc make sed grep awk ar ranlib install diff cmp xargs"
pkg_build_deps="llvm-bootstrap"
pkg_runtime_deps=""
pkg_provides="diff cmp diff3 sdiff"
pkg_outputs="bin/diff bin/cmp"
pkg_configure_opts="--disable-nls"
pkg_validate() { "$DESTDIR$PREFIX/bin/cmp" /dev/null /dev/null; }
