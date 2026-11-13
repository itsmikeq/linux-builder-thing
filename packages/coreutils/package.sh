pkg_name=coreutils
pkg_version=9.5
pkg_stage=1
pkg_source_url="https://ftp.gnu.org/gnu/coreutils/coreutils-${pkg_version}.tar.xz"
pkg_sig_url="${pkg_source_url}.sig"
pkg_verify="gpg-detached:gnu-keyring.gpg"
pkg_sha256=cd328edeac92f6a665de9f323c93b712af1858bc2e0d88f3f7100469470a1b8a
pkg_build_tools="sh cc make sed grep awk ar ranlib install diff cmp xargs"
pkg_build_deps="llvm-bootstrap"
pkg_runtime_deps=""
pkg_provides="cat cp mv rm ln ls mkdir rmdir chmod touch sort uniq tr cut head tail wc expr test [ printf echo env date basename dirname install od uname sleep tee pwd true false mktemp readlink realpath md5sum sha256sum stat dd du df chown id nproc comm join paste seq split csplit nl fold tsort"
pkg_outputs="bin/ls bin/install bin/sort"
# FORCE_UNSAFE_CONFIGURE allows running configure as root inside the QEMU test VM.
pkg_configure_opts="--disable-nls --disable-acl --disable-xattr --without-selinux --without-openssl --enable-no-install-program=kill,uptime,stdbuf"
pkg_configure_env="FORCE_UNSAFE_CONFIGURE=1"
pkg_validate() { [ "$(printf 'b\na\n' | "$DESTDIR$PREFIX/bin/sort" | "$DESTDIR$PREFIX/bin/head" -1)" = a ]; }
