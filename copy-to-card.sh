#!/bin/bash

# Copies the boot and rootfs filesystems to a prepared SD card. 
# Pre-requisites: prepare-card.sh. This script will amost certainly have
#  to be run as root

. ./CONFIG.sh

mkdir -p $MNT_ROOTFS
mkdir -p $MNT_BOOT
mkdir -p $MNT_HOMEFS

echo "Unmount card... ignore errors"

umount ${CARD}1
umount ${CARD}2
umount ${CARD}3

echo "Mounting work areas"

mount ${CARD}1 $MNT_BOOT
mount ${CARD}2 $MNT_ROOTFS
mount ${CARD}3 $MNT_HOMEFS

echo "Cleaning card"

rm -rf $MNT_BOOT/*
rm -rf $MNT_ROOTFS/*

# Don't clean the home partition by default -- it could contain user
#  data. However, we might need to clean it if the contents prevent
#  the new files being installed, for some reason.
#rm -rf $MNT_HOMEFS/*

echo "Copying boot partition"

cp -r ${BOOT}/* $MNT_BOOT/
cp -r bootfiles/* $MNT_BOOT/

echo "Copying root filesystem"

cp -aux ${ROOTFS}/* $MNT_ROOTFS/
chown -R root:root $MNT_ROOTFS/*

echo "Copying user filesystem"

cp -aux ${HOMEFS}/* $MNT_HOMEFS/
chown -R root:root $MNT_HOMEFS/*
chown -R 1000:100 $MNT_HOMEFS/$USER

echo "Setting permissions"

chmod ug+s /$MNT_ROOTFS/usr/bin/sudo
chmod ug+s /$MNT_ROOTFS/bin/ping

echo "Syncing card"

sync

echo "Unmounting card"

umount $MNT_ROOTFS
umount $MNT_BOOT
umount $MNT_HOMEFS

echo "Copy to card done"


