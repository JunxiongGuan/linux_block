#!/bin/bash
# Test target side Device Removal event handling (RDMA)

set -e
. ./nvmf_lib.sh

NAME=selftest-unload-driver-with-open-ctrl
TARGET_DEVICE=/dev/nullb0
TARGET_HOST=
NQN=${NAME}

CLEANUP_ONLY=FALSE
CLEANUP_SKIP=TRUE

BS=32k
DURATION=15
PATTERN=randread
THREADS=1
IODEPTH=4
TARGET_DRIVER=

nvmf_help()
{
    echo $0 ": Help and Usage"
    echo
    echo "Delete a controller during traffic (RDMA)"
    echo
    echo "usage: $0 [options]"
    echo
    echo "Options"
    echo "-------"
    echo
    echo "  -h             : Show this help message"
    echo "  -n NAME        : Controller name on target side"
    echo "  -b TARGET_BLK  : Block device to use on target side"
    echo "  -T TARGET_HOST : Hostname or IP of target side"
    echo "  -d TARGET_DRIVER : rdma device driver"
    echo
}

while getopts "hn:t:T:d:b:p:r:i:" opt; do
    case "$opt" in
	h)  nvmf_help
	    exit 0
	    ;;
	n)  NAME=${OPTARG}
            ;;
	t)  TARGET_DEVICE=${OPTARG}
            ;;
	T)  TARGET_HOST=${OPTARG}
            ;;
	d)  TARGET_DRIVER=${OPTARG}
            ;;
	\?)
	    echo "Invalid option: -$OPTARG" >&2
	    exit 1
	    ;;
	:)
	    echo "Option -$OPTARG requires an argument." >&2
	    exit 1
	    ;;
    esac
done

echo "----------------------------------"
echo "unload driver with open controller"
echo "----------------------------------"

if [ "${TARGET_HOST}" == "" ]; then
    echo "nmvf: No target host specified. Use the -T option."
    exit 1
fi

if [ "${TARGET_DRIVER}" == "" ]; then
    echo "nmvf: No target driver specified. Use the -d option."
    exit 1
fi

  # XXXXX. For now we assume the DUT in a fresh state with none of the
  # relevant modules loaded. We will add checks for this to the script
  # over time.

CONNECTION=$(ssh ${TARGET_HOST} echo \$SSH_CONNECTION)
REMOTE_NODE=$(ssh ${TARGET_HOST} uname -n)
REMOTE_KERNEL=$(ssh ${TARGET_HOST} uname -r)
CARGS=( $CONNECTION )
REMOTE_IP=${CARGS[2]}
LOCAL_IP=${CARGS[0]}
echo "Remote Address: ${REMOTE_IP} ($REMOTE_NODE)"
echo "Remote Device:  ${TARGET_DEVICE}"
echo "Remote Kernel:  ${REMOTE_KERNEL}"
echo
echo "Local Address:  ${LOCAL_IP} ($(uname -n))"
echo "Local Kernel:   $(uname -r)"
echo

nvmf_trap_exit

  # Setup the NVMf target and host.

nvmf_remote_cmd ${TARGET_HOST} nvmf_check_configfs_mount
nvmf_remote_cmd ${TARGET_HOST} nvmf_check_target_device ${TARGET_DEVICE}
nvmf_remote_cmd ${TARGET_HOST} nvmf_rdma_target ${NAME} ${REMOTE_IP}
nvmf_remote_cmd ${TARGET_HOST} nvmf_namespace ${NAME} 1 ${TARGET_DEVICE}

HOST_CTRL=$(nvmf_rdma_host ${NQN} ${REMOTE_IP} 1023)

HOST_CHAR=/dev/${HOST_CTRL}
HOST_DEVICE=/dev/${HOST_CTRL}n1

  # Ensure host mapped drive exists

if [ ! -b "${HOST_DEVICE}" ]
then
    echo nvmf: Error creating host device.
    exit -1
fi

# unload device driver - generate DEVICE_REMOVAL event
echo "Unloading ${TARGET_DRIVER}"
nvmf_remote_cmd ${TARGET_HOST} nvmf_unload_driver ${TARGET_DRIVER}
echo "Done unloading ${TARGET_DRIVER}"

# cleanup the target ctrl
echo "Cleaning ${NAME}"
nvmf_remote_cmd ${TARGET_HOST} nvmf_cleanup_target ${NAME}
echo "Done cleaning ${NAME}"

# delete the host ctrl
echo "Deleting ${HOST_CTRL}"
nvmf_cleanup_host ${NAME}
echo "Done deleting ${HOST_CTRL}"

nvmf_remote_cmd ${TARGET_HOST} nvmf_load_driver ${TARGET_DRIVER}
