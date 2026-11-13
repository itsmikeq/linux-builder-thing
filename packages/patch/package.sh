pkg_name=patch
pkg_version=2.7.6
pkg_stage=1
pkg_source_url="https://ftp.gnu.org/gnu/patch/patch-${pkg_version}.tar.xz"
pkg_sig_url="${pkg_source_url}.sig"
pkg_verify="gpg-detached:gnu-keyring.gpg"
pkg_sha256=ac610bda97abe0d9f6b7c963255a11dcb196c25e337c61f94e4778d632f1d8fd
pkg_build_tools="sh cc make sed grep awk ar ranlib install diff cmp xargs"
pkg_build_deps="llvm-bootstrap"
pkg_runtime_deps=""
pkg_provides="patch"
pkg_outputs="bin/patch"
pkg_validate() { "$DESTDIR$PREFIX/bin/patch" --version | grep -q 'GNU patch'; }
