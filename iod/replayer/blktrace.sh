#!/bin/bash
# device
CHARACTER="nvme1"
NAMESPACE=2
DEV_NAME=$CHARACTER"n"$NAMESPACE
DEV=/dev/$DEV_NAME

OUTPUT_PATH=$1

# blktrace
BLKTRACE_RESULT_PATH="$OUTPUT_PATH/blktrace"

# replayer
REPLAYER_PATH="/root/workspace/script/iod/replayer"
INPUT="$BLKTRACE_RESULT_PATH/trace_nvme1n2.txt"

# blkparse
BLKPARSE_OUTPUT=${BLKTRACE_RESULT_PATH}/replayer_blkparse

# D2C extractor
D2C_extractor_PATH="/root/workspace/script/iod/D2C_extractor"
D2C_READ_OUTPUT=${BLKTRACE_RESULT_PATH}/replayer_d2c_read.txt
D2C_WRITE_OUTPUT=${BLKTRACE_RESULT_PATH}/replayer_d2c_write.txt

pid_kills() {
  PIDS=("${!1}")
  for pid in "${PIDS[*]}"; do
    kill -15 $pid
  done
}

# -d=device, -w=second, -D=output dir
blktrace_start() {
  blktrace -d $DEV -D ${BLKTRACE_RESULT_PATH} >/dev/null &
}

main() {

  if [ ! -d ${BLKTRACE_RESULT_PATH} ]; then
    mkdir -p ${BLKTRACE_RESULT_PATH}
  fi

  if [ $# -ne 1 ]; then
    echo "Need to make input trace path"
    kill -15 $$
  fi

  sleep 1
  sync

  nvme format /dev/nvme1n2 -s 1
  sleep 3

  echo "  Fill..."
  fio --direct=1 --ioengine=libaio --iodepth=64 --filename=$DEV --name=test --rw=write --bs=1M >/dev/null

  echo "  Op Fill..."
  fio --direct=1 --ioengine=libaio --filename=$DEV --name=test --rw=write --iodepth=64 --bs=1M --size=65G >/dev/null

  echo "  blktrace start...   $(date)"
  blktrace_start

  # ${REPLAYER_PATH}/replayer $DEV ${INPUT}
  ./replayer /dev/nvme1n2 ${INPUT}

  echo "  blktrace end..."
  killall blktrace

  echo "  blkparse do..."
  blkparse -i ${BLKTRACE_RESULT_PATH}/$DEV_NAME -o ${BLKPARSE_OUTPUT} >/dev/null

  # rm -rf ${BLKTRACE_RESULT_PATH}/nvme*

  echo "  extract D2C time"
  ${D2C_extractor_PATH}/D2C_extractor ${BLKPARSE_OUTPUT} ${D2C_READ_OUTPUT} ${D2C_WRITE_OUTPUT}

  python3 /root/workspace/script/iod/fio/cdf/cdf_extractor.py ${D2C_READ_OUTPUT}
  source /root/workspace/script/iod/fio/cdf/lat_extractor.sh ${D2C_READ_OUTPUT}_cdf
}

main $1
