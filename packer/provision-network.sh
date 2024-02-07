#!/bin/bash

# RUN BY PACKER ONLY

set -x
set -e

export IMAGE=$(jq -r '.builds[-1].files[-1].name' $MANIFEST)

sudo iscsiadm \
  --mode discovery \
  --type sendtargets \
  --portal ${ISCSI_TARGET_IP}
sudo iscsiadm \
  --mode node \
  --targetname ${ISCSI_TARGET_IQN} \
  --portal ${ISCSI_TARGET_IP} \
  --login

# Hope that this helps iscsiadmin catch up
sleep 3

# Encodes that the trailing number on the hostname is the same as the ISCSI LUN number
ISCSI_DEVICE=/dev/$(sudo iscsiadm -m session -P 3 | grep -A1 'Lun: '$(echo $PI_HOSTNAME | cut -b 4-) | tail -1 | awk '{ print $4 }')
ISCSI_ROOT_PARTITION=${ISCSI_DEVICE}1

sudo parted -s ${ISCSI_DEVICE} mklabel gpt
sudo parted --align optimal ${ISCSI_DEVICE} mkpart primary ext4 0% 100%
# Try to force subsequence call to realize the partition _does_ exist...?
sudo fdisk -l > /dev/null
sudo mke2fs -t ext4 -F -L "${PI_HOSTNAME}root" ${ISCSI_ROOT_PARTITION}

LOOP_DEVICE=$(sudo partx -a -v ${IMAGE} | tr '\n' ' ' | sed -E 's@.*(/dev/loop[0-9]+).*@\1@')

# Copy from image lo device to iscsi root
#############
# DD approach - should be better for fs journal issues?
# sudo dd if=${LOOP_DEVICE}p2 of=${ISCSI_ROOT_PARTITION} bs=32M status=progress
# sudo e2fsck -y -f ${ISCSI_ROOT_PARTITION}
# sudo resize2fs ${ISCSI_ROOT_PARTITION}

###############
# rsync approach - use ONLY this or dd approach
ISCSI_ROOT_DIR="$(mktemp -d)"
IMAGE_ROOT_DIR="$(mktemp -d)"

sudo mount "${ISCSI_ROOT_PARTITION}" ${ISCSI_ROOT_DIR}
sudo mount "${LOOP_DEVICE}p2" ${IMAGE_ROOT_DIR}
sudo rsync -a "${IMAGE_ROOT_DIR}/" ${ISCSI_ROOT_DIR}

sudo umount ${ISCSI_ROOT_DIR}
sudo umount ${IMAGE_ROOT_DIR}

# iscsi no longer needed, clean up and disconnect
sudo iscsiadm -m node -T ${ISCSI_TARGET_IQN} --portal ${ISCSI_TARGET_IP}:3260 -u
sudo iscsiadm -m node -o delete -T ${ISCSI_TARGET_IQN} --portal ${ISCSI_TARGET_IP}:3260

# Set up NFS boot dir from partition 1
NFS_BOOT_DIR="$(mktemp -d)"
IMAGE_BOOT_DIR="$(mktemp -d)"
sudo mount "${LOOP_DEVICE}p1" ${IMAGE_BOOT_DIR}
sudo mount "${NFS_IP}:${NFS_BOOTROOT}" ${NFS_BOOT_DIR}

# TODO only copying the cmdline.txt and config.txt for now, until figure out how to make a working boot partition as part of build/provisioning
sudo rsync -a --delete ${IMAGE_BOOT_DIR}/ ${NFS_BOOT_DIR}/${PI_HOSTNAME}/
# sudo cp ${IMAGE_BOOT_DIR}/cmdline.txt ${IMAGE_BOOT_DIR}/config.txt ${NFS_BOOT_DIR}/${PI_HOSTNAME}/
# Ideally we'd also be creating the right initramfs as part of packer build, too
sudo cp ${NFS_BOOT_DIR}/initrd/latest ${NFS_BOOT_DIR}/${PI_HOSTNAME}/initrd8.img
sudo umount ${NFS_BOOT_DIR}

sudo umount ${IMAGE_BOOT_DIR}
sudo partx --delete -v ${LOOP_DEVICE}
sudo kpartx -d -v ${IMAGE}
