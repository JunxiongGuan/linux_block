#!/bin/bash
# Delete controller during traffic (RDMA)

set -e
. ./nvmf_lib.sh

NAME=selftest-delete-ctrl-during-traffic
TARGET_DEVICE=/dev/nullb0
TARGET_HOST=
NQN=${NAME}

CLEANUP_ONLY=FALSE
CLEANUP_SKIP=FALSE

BS=32k
DURATION=15
PATTERN=randread
THREADS=1
IODEPTH=4

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
    echo "  -d DURATION    : fio duration"
    echo "  -b BS          : fio block size"
    echo "  -p PATTERN     : fio pattern"
    echo "  -r THREADS     : fio number of threads"
    echo "  -i IODEPTH     : fio IO depth"
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
	d)  DURATION=${OPTARG}
            ;;
	b)  BS=${OPTARG}
            ;;
	p)  PATTERN=${OPTARG}
            ;;
	r)  THREADS=${OPTARG}
            ;;
	i)  IODEPTH=${OPTARG}
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
echo "running delete ctrl during traffic"
echo "----------------------------------"

if [ "${TARGET_HOST}" == "" ]; then
    echo "nmvf: No target host specified. Use the -T option."
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

# run fio in the bg
echo "Running fio in the background"
nvmf_run_fio_bg ${BS} ${PATTERN} ${THREADS} ${IODEPTH} ${DURATION} ${HOST_DEVICE}

# Let IO resume
sleep 5

# delete the ctrl
echo "Deleting ${HOST_CTRL}"
nvmf_delete_ctrl ${HOST_CTRL}
echo "Done deleting ${HOST_CTRL}"

sleep 2

# wait for fio
wait
