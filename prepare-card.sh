#!/bin/bash
# Formats an SD card for use. The device should be specified as 
#  CARD in CONFIG.sh. Note that all data will be erased, and no 
#  warning will be given.
# This script will almost certainly have to be run as root or, at least,
#  a user with permissions to operation on block devices.
# This script takes one argument -- the size of the root partition, in Mb.
# This must be at least as large as the size of /tmp/rootfs after build, 
# but can be a little larger to allow for expansion. The opportunities for
#  expansion of a root partition are likely to be limited. If in doubt,
#  use '900' as the argument.
# Three partitions are created: the first is the boot partition, always
#  256 Mb; the second the root partition of the size selected on the
#  command line, and the third -- which will be writable -- the rest of
#  the SD card.

. ./CONFIG.sh

if [ -z "$1" ]; then 
  echo "Usage: ./prepare-card.sh [root_fs_size_mb]"
  exit
fi

ROOTFS_SIZE=$ARG1 

# Ensure that no partition is currrently mounted. Errors from these
#  line can be ignored
umount ${CARD}1
umount ${CARD}2
umount ${CARD}3

sfdisk $CARD  << EOF
,256M,
,${1}M
;
EOF

# Set partition one to type 11 (VFAT)
fdisk $CARD  << EOF
t
1
0b
w
EOF

sync

mkfs.vfat ${CARD}1
mkfs.ext4 -F ${CARD}2
mkfs.ext4 -F ${CARD}3

