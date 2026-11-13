# Statically linked RISC-V clang/clang++/lld + LLVM binutils replacements.
pkg_name=llvm-bootstrap
pkg_version=21.1.8
pkg_stage=0
pkg_source_url="https://github.com/llvm/llvm-project/releases/download/llvmorg-${pkg_version}/llvm-project-${pkg_version}.src.tar.xz"
pkg_sig_url="${pkg_source_url}.sig"
pkg_verify="gpg-detached:release-keys.asc"
pkg_sha256=4633a23617fa31a3ea51242586ea7fb1da7140e426bd62fc164261fe036aa142
pkg_build_tools="cmake ninja cc c++ python3"
pkg_build_deps="musl-cross llvm-runtimes compiler-rt-builtins linux-headers"
pkg_provides="clang clang++ cc c++ cpp ld.lld ld llvm-ar ar llvm-ranlib ranlib llvm-nm nm llvm-objcopy objcopy llvm-objdump objdump llvm-strip strip llvm-readelf readelf llvm-size size llvm-strings strings llvm-addr2line addr2line llvm-cxxfilt c++filt"
pkg_outputs="toolchain/bin/clang toolchain/bin/ld.lld toolchain/bin/llvm-ar"
pkg_host_script="scripts/host/stage0/llvm.sh"
