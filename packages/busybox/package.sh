# Static busybox: the bootstrap shell + core utilities (incl. tar/xz/gzip to
# unpack the bundle). Cross-compiled on the prep host with clang.
pkg_name=busybox
pkg_version=1.37.0
pkg_stage=0
pkg_source_url="https://busybox.net/downloads/busybox-${pkg_version}.tar.bz2"
pkg_sig_url="${pkg_source_url}.sig"
pkg_verify="gpg-detached:busybox-vda.gpg"
pkg_sha256=3311dff32e746499f4df0d5df04d7eb396382d7e108bb9250e7b519b837043a4
pkg_build_tools="make sh sed cc gcc"
pkg_build_deps="musl-cross linux-headers"
# Final applet list is generated from the built binary into build/busybox.applets
pkg_provides="sh ash awk sed grep egrep fgrep tar gzip gunzip zcat bzip2 bunzip2 bzcat xz unxz xzcat cat cp mv rm ln ls mkdir rmdir chmod touch find xargs sort uniq tr cut head tail wc expr test [ printf echo env date basename dirname diff cmp patch install od uname sleep tee pwd true false hostname mktemp readlink realpath md5sum sha256sum stat which bc dd du df mount umount mknod chown id whoami nproc"
pkg_outputs="bootstrap/bin/busybox"
pkg_host_script="scripts/host/stage0/busybox.sh"
