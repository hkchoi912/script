#!/bin/bash

if [ $(id -u) -ne 0 ]
then
  echo "Requires root privileges"
  exit 1
fi

cnt=0
fio_done=0

# device
CHARACTER="nvme1"
NAMESPACE=1
DEV_NAME=$CHARACTER"n"$NAMESPACE
DEV=/dev/$DEV_NAME

# root path
ROOT_PATH=/home/iod/NVMset1/GC/read-dtwin-ndwin-write

# blktrace
BLKTRACE_RESULT_PATH="$ROOT_PATH/blktrace"
RUNTIME=600 # sec

# blkparse
BLKPARSE_OUTPUT=${BLKTRACE_RESULT_PATH}/read-dtwin-ndwin-write-output

# D2C extractor
D2C_extractor_PATH="/home/hkchoi/research/script/iod/D2C_extractor"
D2C_READ_OUTPUT=${BLKTRACE_RESULT_PATH}/read-dtwin-ndwin-write-output-read
D2C_WRITE_OUTPUT=${BLKTRACE_RESULT_PATH}/read-dtwin-ndwin-write-output-write

# window
WINDOW_LOG=${ROOT_PATH}/window.log

main() {
  if [ ! -d ${BLKTRACE_RESULT_PATH} ]; then
    mkdir -p ${BLKTRACE_RESULT_PATH}
  fi

  rm -rf $WINDOW_LOG
  touch $WINDOW_LOG
  rm -rf ${BLKTRACE_RESULT_PATH}/nvme*

  echo "  Format..."
  nvme format $DEV -s 1

  # set PLM
  nvme admin-passthru /dev/nvme1 -n 0x1 -o 0x09 -w --cdw10=0x13 --cdw11=0x01 --cdw12=0x01

  echo "  Fill..."
  fio --direct=1 --ioengine=libaio --iodepth=64 --filename=$DEV --name=test --rw=write --bs=1M >/dev/null

  echo "  fio start...   $(date)"
  # time=msec, lat=nsec
  fio --direct=1 --ioengine=libaio --filename=$DEV --name=test --rw=write --iodepth=64 --bs=1M --size=65G > /dev/null

  echo "  blktrace start...   $(date)"
  blktrace -d $DEV -w $RUNTIME -D ${BLKTRACE_RESULT_PATH} >/dev/null &

  # set DTWIN
  nvme admin-passthru /dev/nvme1 -n 0x1 -o 0x09 -w --cdw10=0x14 --cdw11=0x01 --cdw12=0x01
  sleep 0.02

  echo "  fio start...   $(date)" >> $WINDOW_LOG
  # read test
  fio --direct=1 --ioengine=libaio --filename=$DEV --name=test --rw=randread --iodepth=1 --bs=4K --runtime=$RUNTIME \
  --log_avg_msec=1 --write_lat_log=${BLKTRACE_RESULT_PATH}/read --write_bw_log=${BLKTRACE_RESULT_PATH}/read --output=${ROOT_PATH}/fio.log > /dev/null &

  # window check
  while [ $cnt != $RUNTIME ]; do
    window=$(nvme admin-passthru /dev/nvme1 -n 0x1 -o 0x0a -r --cdw10=0x14 --cdw11=0x01 | tail -c 2)

    if [ $window != "1" ]; then
      if [ $fio_done == "0" ]; then
        fio --direct=1 --ioengine=libaio --filename=$DEV --name=test --rw=randwrite --iodepth=1 --bs=4K --runtime=4 > /dev/null
        fio_done=1
      fi

      nvme admin-passthru /dev/nvme1 -n 0x1 -o 0x09 -w --cdw10=0x14 --cdw11=0x01 --cdw12=0x01

      date +"%H:%M:%S.%N" >> $WINDOW_LOG
    fi

    if [ $window == "1" ]; then
      fio_done=0
    fi

    sleep 1
    # echo $cnt
    cnt=$(($cnt+1))
  done

  # kill blktrace
  pkill -15 blktrace

  echo "  blkparse start...   $(date)"
  blkparse ${BLKTRACE_RESULT_PATH}/${DEV_NAME} -o ${BLKPARSE_OUTPUT} > /dev/null

  echo "  D2C extractor start...   $(date)"
  ${D2C_extractor_PATH}/D2C_extractor ${BLKPARSE_OUTPUT} ${D2C_READ_OUTPUT} ${D2C_WRITE_OUTPUT}

  rm -rf ${BLKTRACE_RESULT_PATH}/nvme*
}

main $1
