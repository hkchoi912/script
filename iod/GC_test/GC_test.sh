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
ROOT_PATH=/home/iod/NVMset4/GC

# blktrace
BLKTRACE_RESULT_PATH="$ROOT_PATH/blktrace"
RUNTIME=1200 # sec

# blkparse
BLKPARSE_OUTPUT=${BLKTRACE_RESULT_PATH}/blktrace_blkparse

# D2C extractor
D2C_extractor_PATH="/home/hkchoi/research/script/iod/D2C_extractor"
D2C_READ_OUTPUT=${BLKTRACE_RESULT_PATH}/blktrace_d2c_read
D2C_WRITE_OUTPUT=${BLKTRACE_RESULT_PATH}/blktrace_d2c_write

pid_kills() {
  PIDS=("${!1}")
  for pid in "${PIDS[*]}"; do
    kill -15 $pid >/dev/null
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
  nvme format $DEV -s 1 -f

  echo "  Fill..."
  fio --direct=1 --ioengine=libaio --iodepth=64 --filename=$DEV --name=test --rw=write --bs=1M >/dev/null

  # FIO_PIDS=()

  # echo "  blktrace start...   $(date)"
  # blktrace_start
  echo "  fio start...   $(date)"

  # time=msec, lat=nsec
  fio --direct=1 --ioengine=libaio --filename=$DEV --name=test --rw=randwrite --iodepth=1 --bs=4K --size=200G \
  # --log_avg_msec=1 \
  --write_lat_log=${BLKTRACE_RESULT_PATH}/lat.log --write_bw_log=${BLKTRACE_RESULT_PATH}/bw.log --output=${ROOT_PATH}/fio.log >/dev/null

  # FIO_PIDS+=("$!")

  # sleep $RUNTIME

  # pid_kills FIO_PIDS[@] >/dev/null

  # echo "  blktrace end..."
  # blktrace_end

  # echo "  blkparse do..."
  # blkparse -i ${BLKTRACE_RESULT_PATH}/$DEV_NAME -o ${BLKPARSE_OUTPUT} >/dev/null

  # rm -rf ${BLKTRACE_RESULT_PATH}/nvme*

  # echo "  extract D2C time"
  # ${D2C_extractor_PATH}/D2C_extractor ${BLKPARSE_OUTPUT} ${D2C_READ_OUTPUT} ${D2C_WRITE_OUTPUT}

}

main $1
