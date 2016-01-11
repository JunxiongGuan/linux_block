#!/bin/bash
# Exercises configure target with a not-exist block device
# and then remove the namespace.

. ./nvmf_lib.sh

NAME=selftest-nvmf
TARGET_DEVICE=/dev/not-exist

nvmf_trap_exit

nvmf_check_configfs_mount
nvmf_target ${NAME}
nvmf_namespace ${NAME} 1 ${TARGET_DEVICE} 2>/dev/null && \
       echo "FAIL: invalid path should not be enabled"

nvmf_cleanup_target ${NAME}
