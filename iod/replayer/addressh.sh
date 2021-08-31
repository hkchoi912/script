#!/bin/bash

if [ $(id -u) -ne 0 ]
then
  echo "Requires root privileges"
  exit 1
fi

# device
CHARACTER="nvme1"
NAMESPACE=4
DEV_NAME=$CHARACTER"n"$NAMESPACE
DEV=/dev/$DEV_NAME

# root path
ROOT_PATH=/home/hkchoi/data/iod/NVMset4/GC

# blktrace
BLKTRACE_RESULT_PATH="$ROOT_PATH/blktrace"
RUNTIME=1200 # sec

# blkparse
BLKPARSE_OUTPUT=${BLKTRACE_RESULT_PATH}/blktrace_blkparse

# D2C extractor
D2C_extractor_PATH="/home/hkchoi/script/iod/D2C_extractor"
D2C_READ_OUTPUT=${BLKTRACE_RESULT_PATH}/blktrace_d2c_read
D2C_WRITE_OUTPUT=${BLKTRACE_RESULT_PATH}/blktrace_d2c_write

pid_kills() {
  PIDS=("${!1}")
  for pid in "${PIDS[*]}"; do
    kill -2 $pid >/dev/null
  done
}

# -d=device, -w=second, -D=output dir
blktrace_start() {
  BLKTRACE_PIDS=()
  blktrace -d $DEV -w $RUNTIME -D ${BLKTRACE_RESULT_PATH} >/dev/null &
  BLKTRACE_PIDS+=("$!")
}

blktrace_end() {
  pid_kills BLKTRACE_PIDS[@]
  sleep 5
}

main() {
  if [ ! -d ${BLKTRACE_RESULT_PATH} ]; then
    mkdir -p ${BLKTRACE_RESULT_PATH}
  fi

  echo "  Format..."
  # nvme format $DEV -s 1 -f

  echo "  Fill..."
  # fio --direct=1 --ioengine=libaio --iodepth=64 --filename=$DEV --name=test --rw=write --bs=1M >/dev/null

  # echo "  blktrace start...   $(date)"
  blktrace_start

  sleep 5

  nvme admin-passthru /dev/nvme1 -n 0x4 -o 0x09 -w --cdw10=0x13 --cdw11=0x04 --cdw12=0x01

  nvme admin-passthru /dev/nvme1 -n 0x4 -o 0x09 -w --cdw10=0x14 --cdw11=0x04 --cdw12=0x01

  sleep 0.02

  echo "  fio start...   $(date)"

  # 32단위로 증가
  ./replayer $DEV 459525208 459526264

  echo "  blktrace end..."
  blktrace_end

  echo "  blkparse do..."
  blkparse -i ${BLKTRACE_RESULT_PATH}/$DEV_NAME -o ${BLKPARSE_OUTPUT} >/dev/null

  rm -rf ${BLKTRACE_RESULT_PATH}/nvme*

  echo "  extract D2C time"
  ${D2C_extractor_PATH}/D2C_extractor ${BLKPARSE_OUTPUT} ${D2C_READ_OUTPUT} ${D2C_WRITE_OUTPUT}

}

main $1
