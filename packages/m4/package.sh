pkg_name=m4
pkg_version=1.4.19
pkg_stage=1
pkg_source_url="https://ftp.gnu.org/gnu/m4/m4-${pkg_version}.tar.xz"
pkg_sig_url="${pkg_source_url}.sig"
pkg_verify="gpg-detached:gnu-keyring.gpg"
pkg_sha256=63aede5c6d33b6d9b13511cd0be2cac046f2e70fd0a07aa9573a04a82783af96
pkg_build_tools="sh cc make sed grep awk ar ranlib install diff cmp xargs"
pkg_build_deps="llvm-bootstrap"
pkg_runtime_deps=""
pkg_provides="m4"
pkg_outputs="bin/m4"
pkg_configure_opts="--disable-nls"
pkg_validate() { echo 'define(X,ok)X' | "$DESTDIR$PREFIX/bin/m4" | grep -qx ok; }
