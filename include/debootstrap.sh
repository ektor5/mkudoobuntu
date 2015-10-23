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

checkroot
umountroot

export LC_ALL=C LANGUAGE=C LANG=C

chroot_cmd(){
  echo $@ | xargs -I% chroot "$ROOTFS/" /bin/bash \
    -c "PATH=/fake:$PATH DEBIAN_FRONTEND=noninteractive %"
}

echo -e "Debootstrapping" >&1 >&2

debootstrap  --foreign \
             --arch=armhf \
             trusty "$ROOTFS" http://127.0.0.1:3142/ports.ubuntu.com

(( $? )) && error "Debootstrap exited with error $?"
             
echo -e "Using emulator to finish install" >&1 >&2
cp /usr/bin/qemu-arm-static "$ROOTFS/usr/bin"
chroot "$ROOTFS/" /bin/bash -c "/debootstrap/debootstrap --second-stage"

mountroot
echo -e "Disabling services" >&1 >&2
mkdir "$ROOTFS/fake"
for i in initctl invoke-rc.d restart start stop start-stop-daemon service
do
  ln -s /bin/true "$ROOTFS/fake/$i" ||
    error "Cannot make link to /bin/true, stopping.."
done

cp patches/gpg.key "$ROOTFS/tmp/"

echo -e "Upgrade, dist-upgrade" >&1 >&2
install -m 644 patches/01proxy          "$ROOTFS/etc/apt/apt.conf.d/01proxy"
install -m 644 patches/sources.list     "$ROOTFS/etc/apt/sources.list"
install -m 644 patches/udoo.list        "$ROOTFS/etc/apt/sources.list.d/udoo.list"
install -m 644 patches/udoo.preferences "$ROOTFS/etc/apt/preferences.d/udoo"

chroot "$ROOTFS/" /bin/bash -c "apt-key add /tmp/gpg.key"
chroot "$ROOTFS/" /bin/bash -c "apt-get -y update"
chroot "$ROOTFS/" /bin/bash -c 'PATH=/fake:$PATH apt-get -y dist-upgrade'
chroot "$ROOTFS/" /bin/bash -c 'PATH=/fake:$PATH apt-get -y -qq install locales'
chroot "$ROOTFS/" /bin/bash -c "locale-gen en_US.UTF-8 it_IT.UTF-8 en_GB.UTF-8"
chroot "$ROOTFS/" /bin/bash -c "export LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8"
chroot "$ROOTFS/" /bin/bash -c "export DEBIAN_FRONTEND=noninteractive"
chroot "$ROOTFS/" /bin/bash -c "update-locale LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LC_MESSAGES=POSIX"

echo -e "Install packages" >&1 >&2
chroot_cmd apt-get install -y ${BASE_PACKAGES[*]} ||
  error "Cannot install BASE packages"

if [ "$BUILD_DESKTOP" = "yes" ]; then
  echo -e "Install desktop environment" >&1 >&2
  chroot_cmd apt-get install -y ${DESKTOP_PACKAGES[*]} ||
    error "Cannot install DESKTOP packages"
fi

echo -e "Cleanup" >&1 >&2
touch "$ROOTFS/etc/init.d/modemmanager"

chroot_cmd apt-get purge -y -qq ${UNWANTED_PACKAGES[*]} ||
  error "Cannot purge UNWANTED packages"

chroot_cmd apt-get autoremove -y || error "Cannot autoremove"
chroot_cmd apt-get clean -y || error "Cannot clean"
chroot_cmd apt-get autoclean -y || error "Cannot autoclean"

rm "$ROOTFS/etc/apt/apt.conf.d/01proxy"
rm -rf "$ROOTFS/fake"

umountroot

echo -n "Saving everything in a tar..."  >&1 >&2
tar -czpf "${ROOTFS}_deboot_$(date +%Y%m%d%H%M).tar.gz" "$ROOTFS"
echo "Done!" >&1 >&2
