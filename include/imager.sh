#!/bin/bash
#
#             UU                                                              
#         U   UU  UU                                                          
#         UU  UU  UU                                                          
#         UU  UU  UU  UU                                                      
#         UU  UU  UU  UU                                                      
#         UU  UUU UU  UU                                 Filesystem Builder   
#                                                                             
#         UUUUUUUUUUUUUU  DDDDDDDDDD         OOOOOOOO         OOOOOOOOO       
#    UUU  UUUUUUUUUUUUUU  DDDDDDDDDDDD     OOOOOOOOOOOO     OOOOOOOOOOOOO     
#     UUU UUUUUUUUUUUUUU  DDDDDDDDDDDDD  OOOOOOOOOOOOOOOO  OOOOOOOOOOOOOOOO   
#       UUUUUUUUUUUUUUUU  DDDDDDDDDDDDD  OOOOOOOOOOOOOOOO  OOOOOOOOOOOOOOOO   
#        UUUUUUUUUUUUUU   DDDDDDDDDDDDD  OOOOOOOOOOOOOOOO  OOOOOOOOOOOOOOOO   
#          UUUUUUUUUUUU   DDDDDDDDDDDD    OOOOOOOOOOOOOO    OOOOOOOOOOOOOO    
#           UUUUUUUUUU    DDDDDDDDDDD       OOOOOOOOOO        OOOOOOOOOO      
#
#   Author: Francesco Montefoschi <francesco.monte@gmail.com>
#   Author: Ettore Chimenti <ek5.chimenti@gmail.com>
#   Based on: Igor Pečovnik's work - https://github.com/igorpecovnik/lib
#   License: GNU GPL version 2
#
################################################################################

if [ "$BUILD_DESKTOP" = "yes" ]; then
	SDSIZE=$(( $SDSIZE + 2000 ))
fi

echo -e "Creating a $SDSIZE MB image..."
dd if=/dev/zero of=$OUTPUT bs=1M count=$SDSIZE status=noxfer >/dev/null 2>&1
LOOP=$(losetup -f)
losetup $LOOP $OUTPUT

OFFSET="1"
BOOTSIZE="32"
BOOTSTART=$(($OFFSET*2048))
ROOTSTART=$(($BOOTSTART+($BOOTSIZE*2048)))
BOOTEND=$(($ROOTSTART-1))

echo -e "Creating image partitions"
# Create partitions and file-system
parted -s $LOOP -- mklabel msdos
parted -s $LOOP -- mkpart primary fat16  $BOOTSTART"s" $BOOTEND"s"
parted -s $LOOP -- mkpart primary ext4  $ROOTSTART"s" -1s
partprobe $LOOP
mkfs.vfat -n "BOOT" $LOOP"p1" >/dev/null 2>&1
mkfs.ext4 -q $LOOP"p2"

mkdir sdcard 2> /dev/null
mount $LOOP"p2" sdcard
mkdir sdcard/boot
mkdir sdcard/dev
mkdir sdcard/proc
mkdir sdcard/run
mkdir sdcard/mnt
mkdir sdcard/tmp
chmod o+t,ugo+rw sdcard/tmp
mount $LOOP"p1" sdcard/boot

rm -rf rootfs/home/ubuntu #temp fix, we need to move the files later

echo -e "Copying filesystem on SD image..."
rsync -a --exclude run --exclude tmp --exclude qemu-arm-static rootfs/ sdcard/
ln -s /run sdcard/var/run
ln -s /run/network sdcard/etc/network/run
mkdir sdcard/var/tmp
chmod o+t,ugo+rw sdcard/var/tmp

echo -e "Writing U-BOOT"
# write bootloader
dd if=$UBOOT of=$LOOP bs=1k seek=1
sync

umount -l sdcard/boot
umount -l sdcard

losetup -d $LOOP
sync

echo -e "Build complete!"
