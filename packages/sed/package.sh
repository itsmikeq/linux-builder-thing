pkg_name=sed
pkg_version=4.9
pkg_stage=1
pkg_source_url="https://ftp.gnu.org/gnu/sed/sed-${pkg_version}.tar.xz"
pkg_sig_url="${pkg_source_url}.sig"
pkg_verify="gpg-detached:gnu-keyring.gpg"
pkg_sha256=6e226b732e1cd739464ad6862bd1a1aba42d7982922da7a53519631d24975181
pkg_build_tools="sh cc make sed grep awk ar ranlib install diff cmp xargs"
pkg_build_deps="llvm-bootstrap"
pkg_runtime_deps=""
pkg_provides="sed"
pkg_outputs="bin/sed"
pkg_configure_opts="--disable-nls --disable-acl --without-selinux"
pkg_validate() { [ "$(echo abc | "$DESTDIR$PREFIX/bin/sed" s/b/X/)" = aXc ]; }
# Not needed: generated files ship in the release tarball / used only by tests or optional features.
pkg_optional_tools="perl"
