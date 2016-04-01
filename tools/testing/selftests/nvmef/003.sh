#!/bin/bash

# Reproduce deadlock between async events notification
# and namespace removal in the loop driver
#

. ./nvmf_lib.sh

# default to 5 devices
nr_devs=${1:-5}

CLEANUP_ONLY=FALSE
CLEANUP_SKIP=FALSE

CFGFS=/sys/kernel/config/nvmet
NAME="test"

# Reload null_blk
rmmod null_blk > /dev/null 2>&1
modprobe null_blk nr_devices=$nr_devs

nvmf_trap_exit

# Create subsys with #nr_devs
nvmf_check_configfs_mount
nvmf_loop_target ${NAME}

j=0
for i in `seq $nr_devs`; do
        nvmf_namespace ${NAME} $i "/dev/nullb$j"
        let "j+=1"
done

# Connect nvme-loop
HOST_CTRL=$(nvmf_loop_host ${NAME})

# Let ns scan complete
sleep 2

# delete the loop controller
nvmf_delete_ctrl ${HOST_CTRL}
