#!/bin/bash

# Clean up after building rasp-pi-min-ro-build. There should be no need
#  to run this script as root
# Please note that the cache directory is not cleared -- there should really
#  never be a need to clear it, unless it's eating too much disk space

. ./CONFIG.sh

rm -rf $TMP/firmware-master
rm -rf $TMP/firmware.zip
rm -rf $TMP/rootfs
rm -rf $TMP/boot
rm -rf $TMP/homefs

