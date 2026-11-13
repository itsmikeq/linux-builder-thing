#!/usr/bin/env bash
# PREP HOST: compiler-rt builtins + crtbegin/crtend for riscv64-unknown-linux-musl.
. "$(dirname "$0")/../common.sh"
done_p compiler-rt-builtins && { msg "compiler-rt already done"; exit 0; }
setup_xres
src=$(srcdir compiler-rt-builtins)
B=$S0/compiler-rt-build; rm -rf "$B"
msg "compiler-rt builtins"
{
cmake -G Ninja -S "$src/compiler-rt" -B "$B" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=riscv64 \
  -DCMAKE_C_COMPILER=$HOST_CC -DCMAKE_CXX_COMPILER=$HOST_CXX -DCMAKE_ASM_COMPILER=$HOST_CC \
  -DCMAKE_AR=$(command -v $HOST_AR) -DCMAKE_RANLIB=$(command -v $HOST_RANLIB) -DCMAKE_NM=$(command -v $HOST_NM) \
  -DCMAKE_C_COMPILER_TARGET=$TARGET -DCMAKE_CXX_COMPILER_TARGET=$TARGET -DCMAKE_ASM_COMPILER_TARGET=$TARGET \
  -DCMAKE_SYSROOT="$SYSROOT" -DCMAKE_C_FLAGS="$ARCHFLAGS" -DCMAKE_ASM_FLAGS="$ARCHFLAGS" -DCMAKE_CXX_FLAGS="$ARCHFLAGS" \
  -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
  -DCMAKE_INSTALL_PREFIX="$B/install" \
  -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
  -DCOMPILER_RT_BUILD_BUILTINS=ON -DCOMPILER_RT_BUILD_CRT=ON \
  -DCOMPILER_RT_BUILD_SANITIZERS=OFF -DCOMPILER_RT_BUILD_XRAY=OFF -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
  -DCOMPILER_RT_BUILD_PROFILE=OFF -DCOMPILER_RT_BUILD_MEMPROF=OFF -DCOMPILER_RT_BUILD_ORC=OFF \
  -DCOMPILER_RT_BUILD_CTX_PROFILE=OFF -DCOMPILER_RT_BUILD_GWP_ASAN=OFF \
  -DCOMPILER_RT_INCLUDE_TESTS=OFF
ninja -C "$B" -j"$JOBS" install
} >"$LOGDIR/compiler-rt.log" 2>&1 || die "compiler-rt failed; see $LOGDIR/compiler-rt.log"
lib=$(find "$B/install" -name 'libclang_rt.builtins*.a' | head -1)
[ -n "$lib" ] || die "builtins archive not produced"
libdir=$(dirname "$lib")
# Host-clang private resource dir (for cross-building) and the final toolchain resource dir.
for d in "$XRES/lib/$TARGET" "$TC/lib/clang/$LLVM_MAJOR/lib/$TARGET"; do
  mkdir -p "$d"; cp -a "$libdir"/. "$d"/
done
ls -l "$XRES/lib/$TARGET"
stamp compiler-rt-builtins
