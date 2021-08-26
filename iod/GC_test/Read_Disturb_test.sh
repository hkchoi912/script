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
ROOT_PATH=/home/iod/NVMset4/Read_Disturb

# blktrace
BLKTRACE_RESULT_PATH="$ROOT_PATH/blktrace"
RUNTIME=1200 # sec

# blkparse
BLKPARSE_OUTPUT=${BLKTRACE_RESULT_PATH}/blktrace_blkparse

# D2C extractor
# D2C_extractor_PATH="/home/hkchoi/research/script/iod/D2C_extractor"
# D2C_READ_OUTPUT=${BLKTRACE_RESULT_PATH}/blktrace_d2c_read
# D2C_WRITE_OUTPUT=${BLKTRACE_RESULT_PATH}/blktrace_d2c_write

# window
WINDOW_LOG=${ROOT_PATH}/window.log

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
  rm -rf $WINDOW_LOG
  touch $WINDOW_LOG

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

  echo "  PLM start...   $(date +"%Y-%m-%d %H:%M:%S.%N")"
  nvme admin-passthru /dev/nvme1 -n 1 -o 0x09 -w --cdw10=0x13 --cdw11=0x01 --cdw12=0x01
  echo "  DTWIN start...   $(date +"%Y-%m-%d %H:%M:%S.%N")"
  nvme admin-passthru /dev/nvme1 -n 0x1 -o 0x09 -w --cdw10=0x14 --cdw11=0x01 --cdw12=0x01

  echo "  fio start...   $(date +"%Y-%m-%d %H:%M:%S.%N")"
  # time=msec, lat=nsec
  fio --direct=1 --ioengine=libaio --filename=$DEV --name=test --rw=read --iodepth=1 --bs=4K --runtime=$RUNTIME  \
  # --log_avg_msec=1 \
  --write_lat_log=${BLKTRACE_RESULT_PATH}/lat.log --write_bw_log=${BLKTRACE_RESULT_PATH}/bw.log --output=${ROOT_PATH}/fio.log >/dev/null &

  # window check
  while [ 1 -eq 1 ]; do
    window=$(nvme get-feature $DEV -n 1 -f 20 -c 1 | tail -c 2)

    if [ $window == "2" ]; then
        nvme admin-passthru $DEV -n 0x1 -o 0x09 -w --cdw10=0x14 --cdw11=0x01 --cdw12=0x01
        date +"%Y-%m-%d %H:%M:%S.%N" >> $WINDOW_LOG
    fi

    sleep 0.01
  done

}

main $1
