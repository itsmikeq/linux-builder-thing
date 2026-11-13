pkg_name=tar
pkg_version=1.35
pkg_stage=1
pkg_source_url="https://ftp.gnu.org/gnu/tar/tar-${pkg_version}.tar.xz"
pkg_sig_url="${pkg_source_url}.sig"
pkg_verify="gpg-detached:gnu-keyring.gpg"
pkg_sha256=4d62ff37342ec7aed748535323930c7cf94acf71c3591882b26a7ea50f3edc16
pkg_build_tools="sh cc make sed grep awk ar ranlib install diff cmp xargs"
pkg_build_deps="llvm-bootstrap"
pkg_runtime_deps=""
pkg_provides="tar"
pkg_outputs="bin/tar"
pkg_configure_opts="--disable-nls --without-selinux --disable-acl --without-xattrs"
pkg_configure_env="FORCE_UNSAFE_CONFIGURE=1"
pkg_validate() { "$DESTDIR$PREFIX/bin/tar" --version | grep -q 'GNU tar'; }
# Not needed: generated files ship in the release tarball / used only by tests or optional features.
pkg_optional_tools="yacc"
