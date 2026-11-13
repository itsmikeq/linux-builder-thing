# compiler-rt builtins (libgcc replacement) for riscv64-unknown-linux-musl.
pkg_name=compiler-rt-builtins
pkg_version=21.1.8
pkg_stage=0
pkg_source_url="https://github.com/llvm/llvm-project/releases/download/llvmorg-${pkg_version}/llvm-project-${pkg_version}.src.tar.xz"
pkg_sig_url="${pkg_source_url}.sig"
pkg_verify="gpg-detached:release-keys.asc"
pkg_sha256=4633a23617fa31a3ea51242586ea7fb1da7140e426bd62fc164261fe036aa142
pkg_build_tools="cmake ninja cc python3"
pkg_build_deps="musl-headers linux-headers"
pkg_outputs="toolchain/lib/clang/21/lib/riscv64-unknown-linux-musl/libclang_rt.builtins.a"
pkg_host_script="scripts/host/stage0/compiler-rt.sh"
