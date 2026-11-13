/* RISC-V TARGET: report kernel features the bootstrap relies on.
 * Does NOT assume support: each syscall is invoked and ENOSYS is reported. */
#define _GNU_SOURCE
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/syscall.h>
#include <sys/utsname.h>
#include <sys/auxv.h>

struct sc { const char *name; long nr; int required; const char *why; };
#ifndef SYS_riscv_flush_icache
#define SYS_riscv_flush_icache 259
#endif
static const struct sc tab[] = {
  {"openat",        SYS_openat, 1, "all file access (musl)"},
  {"clone",         SYS_clone, 1, "fork/pthreads"},
  {"execve",        SYS_execve, 1, "running tools"},
  {"wait4",         SYS_wait4, 1, "make/sh"},
  {"pipe2",         SYS_pipe2, 1, "shell pipelines"},
  {"getdents64",    SYS_getdents64, 1, "directory listing"},
  {"mmap",          SYS_mmap, 1, "malloc"},
  {"futex",         SYS_futex, 1, "threads (LLVM uses threads)"},
  {"riscv_flush_icache", SYS_riscv_flush_icache, 1, "__clear_cache (libgcc/compiler-rt)"},
  {"getrandom",     SYS_getrandom, 0, "musl falls back"},
  {"statx",         SYS_statx, 0, "coreutils falls back to fstatat"},
  {"copy_file_range", SYS_copy_file_range, 0, "coreutils cp falls back"},
  {"renameat2",     SYS_renameat2, 0, "mv falls back"},
  {"faccessat2",    SYS_faccessat2, 0, "musl falls back to faccessat"},
  {"memfd_create",  SYS_memfd_create, 0, "optional"},
  {"close_range",   SYS_close_range, 0, "optional"},
  {"openat2",       SYS_openat2, 0, "optional"},
  {"pidfd_open",    SYS_pidfd_open, 0, "optional"},
#ifdef SYS_riscv_hwprobe
  {"riscv_hwprobe", SYS_riscv_hwprobe, 0, "optional (Linux >= 6.4)"},
#endif
};

int main(void) {
  struct utsname u; uname(&u);
  printf("kernel: %s %s %s\n", u.sysname, u.release, u.machine);
  printf("page size: %ld\n", sysconf(_SC_PAGESIZE));
  unsigned long hw = getauxval(AT_HWCAP);
  printf("AT_HWCAP: 0x%lx (", hw);
  for (int i = 0; i < 26; i++) if (hw & (1UL << i)) putchar('a' + i);
  printf(")\n");
  int missing_required = 0;
  for (unsigned i = 0; i < sizeof tab / sizeof *tab; i++) {
    /* Invalid args: we only care whether the kernel knows the syscall. */
    errno = 0;
    long r = syscall(tab[i].nr, -1L, 0L, 0L, 0L, 0L, 0L);
    int ok = !(r == -1 && errno == ENOSYS);
    printf("%-20s %-8s %s%s\n", tab[i].name, ok ? "present" : "ENOSYS", tab[i].why,
           (!ok && tab[i].required) ? "  <-- REQUIRED" : "");
    if (!ok && tab[i].required) missing_required++;
  }
  int need = (hw & (1UL << ('i'-'a'))) && (hw & (1UL << ('m'-'a'))) && (hw & (1UL << ('a'-'a'))) &&
             (hw & (1UL << ('f'-'a'))) && (hw & (1UL << ('d'-'a'))) && (hw & (1UL << ('c'-'a')));
  printf("RV64GC (imafdc) in HWCAP: %s\n", need ? "yes" : "NO");
  return (missing_required || !need) ? 1 : 0;
}
