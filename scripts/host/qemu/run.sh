#!/usr/bin/env bash
# PREP HOST: boot QEMU riscv64 'virt' (TCG, no network) and run an operator script
# on the work disk as the simulated vendor OS would.
#   run.sh <work.img>   [env: QEMU_SMP=4 QEMU_MEM=4G QEMU_TIMEOUT=seconds]
. "$(dirname "$0")/../common.sh"
IMG=${1:?usage: run.sh work.img}
OUT=$RBS_ROOT/output/qemu
SMP=${QEMU_SMP:-4} MEM=${QEMU_MEM:-4G}
# Plain RV64GC (+ the Zicsr/Zifencei/Zca... that G/C imply): QEMU's default rv64 CPU also
# offers Zb*/Zfa/H/..., which real RV64GC hardware may lack. Nothing may depend on them.
CPU=${QEMU_CPU:-rv64,zba=false,zbb=false,zbc=false,zbs=false,zfa=false,h=false,zawrs=false,zihintntl=false,zicbom=false,zicboz=false,svadu=false}
CON=${QEMU_LOG:-$RBS_ROOT/logs/qemu-console.log}
msg "qemu-system-riscv64 virt smp=$SMP mem=$MEM (network disabled) console -> $CON"
timeout "${QEMU_TIMEOUT:-86400}" qemu-system-riscv64 \
  -machine virt -cpu "$CPU" -smp "$SMP" -m "$MEM" -nographic -no-reboot \
  -bios default -kernel "$OUT/Image" -initrd "$OUT/initramfs.cpio.gz" \
  -append "console=ttyS0 rdinit=/init quiet" \
  -drive file="$IMG",format=raw,if=virtio,cache=writeback \
  -nic none </dev/null 2>&1 | tee "$CON" | grep -a --line-buffered -E '^(rbs:|RBS|PASS|FAIL|SELFTEST|###)' || true
rc=$(tr -d '\r' < "$CON" | sed -n 's/^RBS-EXIT=\([0-9]*\).*/\1/p' | tail -1)
[ -n "$rc" ] || die "guest did not report an exit status (crash/timeout); see $CON"
exit "$rc"
