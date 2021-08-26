#!/bin/bash
# device
CHARACTER="nvme1"
NAMESPACE=4
DEV_NAME=$CHARACTER"n"$NAMESPACE
DEV=/dev/$DEV_NAME

# blktrace
BLKTRACE_RESULT_PATH="/home/iod/NVMset4/blktrace"
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
    sudo kill -15 $pid >/dev/null
  done
}

# -d=device, -w=second, -D=output dir
blktrace_start() {
  BLKTRACE_PIDS=()
  sudo blktrace -d $DEV -w $RUNTIME -D ${BLKTRACE_RESULT_PATH} >/dev/null &
  BLKTRACE_PIDS+=("$!")
}

blktrace_end() {
  pid_kills BLKTRACE_PIDS[@]
  sleep 5
}

main() {
  echo "  Format..."
  sudo nvme format $DEV -s 1 -f

  echo "  Fill..."
  sudo fio --ioengine=libaio --iodepth=64 --filename=$DEV --name=test --rw=write --bs=1MB --fill_device=1 >/dev/null

  # FIO_PIDS=()

  # echo "  blktrace start...   $(date)"
  # blktrace_start
  echo "  fio start...   $(date)"

  # time=msec, lat=nsec
  sudo fio --ioengine=libaio --filename=$DEV --name=test --rw=randwrite --iodepth=1 --bs=4KB --size=200GB \
  --log_avg_msec=1 --write_lat_log=${BLKTRACE_RESULT_PATH}/lat.log --write_bw_log=${BLKTRACE_RESULT_PATH}/bw.log >/dev/null

  # FIO_PIDS+=("$!")

  # sleep $RUNTIME

  # pid_kills FIO_PIDS[@] >/dev/null

  # echo "  blktrace end..."
  # blktrace_end

  # echo "  blkparse do..."
  # blkparse -i ${BLKTRACE_RESULT_PATH}/$DEV_NAME -o ${BLKPARSE_OUTPUT} >/dev/null

  # sudo rm -rf ${BLKTRACE_RESULT_PATH}/nvme*

  # echo "  extract D2C time"
  # ${D2C_extractor_PATH}/D2C_extractor ${BLKPARSE_OUTPUT} ${D2C_READ_OUTPUT} ${D2C_WRITE_OUTPUT}

}

main $1
