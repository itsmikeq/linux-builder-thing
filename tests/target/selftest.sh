#!/bin/sh
# RISC-V TARGET: validate the bootstrap toolchain natively (Stage 1 entry check).
# Verifies: we run on riscv64; clang/clang++/lld compile, link and RUN C and C++;
# outputs are static RISC-V ELF; no vendor tools are on PATH.
set -eu
RBS=${RBS:?}
. "$RBS/scripts/target/lib.sh"
rbs_env clang
T=$RBS/tmp/selftest; rm -rf "$T"; mkdir -p "$T"; cd "$T"
fail=0
ok()  { echo "PASS: $*"; }
bad() { echo "FAIL: $*"; fail=1; }

m=$(uname -m)
[ "$m" = riscv64 ] && ok "uname -m = riscv64" || bad "uname -m = $m (not running on RISC-V?)"
grep -qi 'isa' /proc/cpuinfo && ok "cpu isa: $(grep -m1 -i '^isa' /proc/cpuinfo | sed 's/.*: //')" || bad "no isa line in /proc/cpuinfo"

for t in clang clang++ ld.lld llvm-ar llvm-nm busybox; do
  p=$(command -v $t) || { bad "$t not on PATH"; continue; }
  is_static_riscv "$(readlink -f "$p")" && ok "$t is static RISC-V ($p)" || bad "$t is not a static RISC-V binary"
done
case ":$PATH:" in *:/bin:*|*:/usr/bin:*|*:/sbin:*|*:/usr/sbin:*) bad "vendor directories on PATH: $PATH" ;; *) ok "PATH is hermetic: $PATH" ;; esac

cat > hello.c <<'C'
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <pthread.h>
static void *thr(void *a) { return (void *)((long)a * 2); }
int main(void) {
  pthread_t t; void *r;
  pthread_create(&t, 0, thr, (void *)21); pthread_join(t, &r);
  printf("hello %ld %.3f\n", (long)r, sqrt(2.0));
  return 0;
}
C
cat > hello.cc <<'C'
#include <iostream>
#include <vector>
#include <string>
#include <stdexcept>
#include <algorithm>
int main() {
  std::vector<std::string> v{"c", "a", "b"};
  std::sort(v.begin(), v.end());
  try { throw std::runtime_error("unwind"); }
  catch (const std::exception &e) { std::cout << v[0] << v[1] << v[2] << " " << e.what() << "\n"; }
  return 0;
}
C
if clang -O2 hello.c -o hello-c -lm -pthread 2>err.txt; then
  out=$(./hello-c) && [ "$out" = "hello 42 1.414" ] && ok "C compile+link+run: $out" || bad "C program output: '$out'"
  is_static_riscv hello-c && ok "C output is static RISC-V" || bad "C output not static"
else bad "C compile failed: $(cat err.txt)"; fi
if clang++ -O2 hello.cc -o hello-cxx 2>err.txt; then
  out=$(./hello-cxx) && [ "$out" = "abc unwind" ] && ok "C++ (libc++, exceptions/libunwind) run: $out" || bad "C++ output: '$out'"
else bad "C++ compile failed: $(cat err.txt)"; fi
# separate compile, archive, link with lld
echo 'int f(void){return 7;}' > f.c
echo 'int f(void); int main(void){return f()==7?0:1;}' > m.c
if clang -c f.c && llvm-ar rcs libf.a f.o && clang m.c -L. -lf -o m && ./m; then ok "archive + lld link"; else bad "archive/link"; fi
# assembler
printf '.globl main\nmain:\n li a0, 0\n ret\n' > a.S
clang a.S -o a && ./a && ok "integrated assembler" || bad "assembler"

[ $fail = 0 ] && echo "SELFTEST: ALL PASSED" || { echo "SELFTEST: FAILURES"; exit 1; }
