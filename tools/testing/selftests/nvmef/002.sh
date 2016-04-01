#!/bin/bash
# Exercises FLUSH request

DEVICE=nvme0n1
MNT=/mnt

transport=/sys/block/$DEVICE/device/transport

if [ ! -f $transport ] ; then
	echo "Must be a NVMe device"
	exit -1
fi

if [ "`cat $transport`" != "rdma" ] ; then
	echo "Must be a RDMA NVMeOF device"
	exit -1
fi

which wipefs > /dev/null
if [ $? -ne 0 ] ; then
	echo "Please install wipefs"
	exit -1
fi

which mkfs.ext4 > /dev/null
if [ $? -ne 0 ] ; then
	echo "Please install mkfs.ext4"
	exit -1
fi

wipefs -a /dev/$DEVICE
mkfs.ext4 /dev/$DEVICE
mount /dev/$DEVICE $MNT
dd if=/dev/zero of=${MNT}/test.file bs=4k count=10000 oflag=direct
umount $MNT
echo 1 > /sys/block/$DEVICE/device/delete_controller

