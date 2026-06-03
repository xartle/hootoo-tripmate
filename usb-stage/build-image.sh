#!/bin/bash
# Build the `extern_package` ext2 loop image from extern_root/.
# Drop the result at the root of a FAT32 USB stick for the TripMate.
#
# The static mipsel BusyBox in extern_root/opt/bin/busybox came from:
#   https://busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-mipsel
#   md5 e3f48591199eaa0ef4b287c144de4c12  (ELF32 LSB MIPS, statically linked, mips1/o32)
# Re-fetch with:  curl -O <url above>  (then verify md5, place at extern_root/opt/bin/busybox)
#
# Requires e2fsprogs >= 1.43 (for `mke2fs -d`, which populates without root/loop-mount).
set -e
cd "$(dirname "$0")"
SIZE_BLOCKS=${1:-8192}     # 1K blocks -> default 8 MB
rm -f extern_package
mke2fs -q -F -t ext2 -b 1024 -L TRIPPY -d extern_root extern_package "$SIZE_BLOCKS"
echo "built extern_package ($(stat -c%s extern_package) bytes) from extern_root/"
echo "busybox md5: $(md5sum extern_root/opt/bin/busybox | cut -d' ' -f1)"
