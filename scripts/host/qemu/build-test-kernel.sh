#!/usr/bin/env bash
# PREP HOST (test infrastructure only): an upstream riscv64 kernel for QEMU 'virt'
# that STANDS IN for the unavailable vendor kernel. It is NOT part of the bundle and
# says nothing about vendor hardware support. Built with LLVM=1.
. "$(dirname "$0")/../common.sh"
OUT=$RBS_ROOT/output/qemu; mkdir -p "$OUT"
[ -f "$OUT/Image" ] && [ -z "${FORCE:-}" ] && { msg "test kernel exists"; exit 0; }
src=$(srcdir linux-headers)
K=$S0/test-kernel
if [ -x "$HL/clang" ]; then LLVMSFX=; LLVMDIR="LLVM=$HL/"; else LLVMDIR="LLVM=-18"; fi
KM=(make -C "$src" O="$K" ARCH=riscv $LLVMDIR HOSTCC=gcc KBUILD_BUILD_TIMESTAMP="1970-01-01" KBUILD_BUILD_USER=rbs KBUILD_BUILD_HOST=rbs)
msg "test kernel defconfig + build ($LLVMDIR)"
{
"${KM[@]}" defconfig
"$src/scripts/config" --file "$K/.config" \
  -e DEVTMPFS -e DEVTMPFS_MOUNT -e VIRTIO_BLK -e VIRTIO_PCI -e VIRTIO_MMIO -e EXT4_FS \
  -e BLK_DEV_INITRD -e NET_9P -e NET_9P_VIRTIO -e 9P_FS -e TMPFS -e PROC_FS -e SYSFS \
  -e SERIAL_8250 -e SERIAL_8250_CONSOLE -e SERIAL_OF_PLATFORM -d MODULES -d DEBUG_INFO \
  -d DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT -e DEBUG_INFO_NONE
"${KM[@]}" olddefconfig
"${KM[@]}" -j"$JOBS" Image
} >"$LOGDIR/test-kernel.log" 2>&1 || die "test kernel failed; see $LOGDIR/test-kernel.log"
cp "$K/arch/riscv/boot/Image" "$OUT/Image"
cp "$K/.config" "$OUT/kernel.config"
ls -l "$OUT/Image"
