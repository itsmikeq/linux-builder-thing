#!/usr/bin/env bash
# PREP HOST: static libunwind, libc++abi, libc++ for riscv64 musl, into the sysroot.
. "$(dirname "$0")/../common.sh"
done_p llvm-runtimes && { msg "llvm-runtimes already done"; exit 0; }
setup_xres
src=$(srcdir llvm-runtimes)
B=$S0/runtimes-build; rm -rf "$B"
msg "libunwind/libc++abi/libc++"
{
cmake -G Ninja -S "$src/runtimes" -B "$B" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=riscv64 \
  -DCMAKE_C_COMPILER=$HOST_CC -DCMAKE_CXX_COMPILER=$HOST_CXX -DCMAKE_ASM_COMPILER=$HOST_CC \
  -DCMAKE_AR=$(command -v $HOST_AR) -DCMAKE_RANLIB=$(command -v $HOST_RANLIB) -DCMAKE_NM=$(command -v $HOST_NM) \
  -DCMAKE_C_COMPILER_TARGET=$TARGET -DCMAKE_CXX_COMPILER_TARGET=$TARGET -DCMAKE_ASM_COMPILER_TARGET=$TARGET \
  -DCMAKE_SYSROOT="$SYSROOT" \
  -DCMAKE_C_FLAGS="$ARCHFLAGS -resource-dir=$XRES" -DCMAKE_CXX_FLAGS="$ARCHFLAGS -resource-dir=$XRES" \
  -DCMAKE_ASM_FLAGS="$ARCHFLAGS -resource-dir=$XRES" \
  -DCMAKE_EXE_LINKER_FLAGS="$XLDFLAGS -nostdlib++" -DCMAKE_SHARED_LINKER_FLAGS="$XLDFLAGS -nostdlib++" \
  -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DLLVM_ENABLE_RUNTIMES="libunwind;libcxxabi;libcxx" \
  -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=OFF -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_DOCS=OFF \
  -DLIBUNWIND_ENABLE_SHARED=OFF -DLIBUNWIND_USE_COMPILER_RT=ON \
  -DLIBCXXABI_ENABLE_SHARED=OFF -DLIBCXXABI_USE_COMPILER_RT=ON -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
  -DLIBCXX_ENABLE_SHARED=OFF -DLIBCXX_HAS_MUSL_LIBC=ON -DLIBCXX_USE_COMPILER_RT=ON \
  -DLIBCXX_CXX_ABI=libcxxabi -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON \
  -DLIBCXX_INCLUDE_BENCHMARKS=OFF -DLIBCXX_INCLUDE_TESTS=OFF
ninja -C "$B" -j"$JOBS"
DESTDIR="$SYSROOT" ninja -C "$B" install
} >"$LOGDIR/llvm-runtimes.log" 2>&1 || die "runtimes failed; see $LOGDIR/llvm-runtimes.log"
ls -l "$SYSROOT/usr/lib/"lib{c++,c++abi,unwind}.a
stamp llvm-runtimes
