#!/bin/bash
# device
CHARACTER="nvme1"
NAMESPACE=4
DEV_NAME=$CHARACTER"n"$NAMESPACE
DEV=/dev/$DEV_NAME

# blktrace
BLKTRACE_RESULT_PATH="/home/iod/NVMset4/Read_Disturb/blktrace"
RUNTIME=1200 # sec

# blkparse
BLKPARSE_OUTPUT=${BLKTRACE_RESULT_PATH}/blktrace_blkparse

# D2C extractor
# D2C_extractor_PATH="/home/hkchoi/research/script/iod/D2C_extractor"
# D2C_READ_OUTPUT=${BLKTRACE_RESULT_PATH}/blktrace_d2c_read
# D2C_WRITE_OUTPUT=${BLKTRACE_RESULT_PATH}/blktrace_d2c_write

# window
WINDOW_LOG=${BLKTRACE_RESULT_PATH}/window.log

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
  sudo rm -rf $WINDOW_LOG

  echo "  Format..."
  sudo nvme format $DEV -s 1 -f

  echo "  Fill..."
  sudo fio --ioengine=libaio --iodepth=64 --filename=$DEV --name=test --rw=write --bs=1MB --fill_device=1 >/dev/null

  # FIO_PIDS=()

  # echo "  blktrace start...   $(date)"
  # blktrace_start

  echo "  PLM start...   $(date +"%Y-%m-%d %H:%M:%S.%N")"
  sudo nvme admin-passthru /dev/nvme1 -n 1 -o 0x09 -w --cdw10=0x13 --cdw11=0x01 --cdw12=0x01
  echo "  DTWIN start...   $(date +"%Y-%m-%d %H:%M:%S.%N")"
  sudo nvme admin-passthru /dev/nvme1 -n 0x1 -o 0x09 -w --cdw10=0x14 --cdw11=0x01 --cdw12=0x01

  echo "  fio start...   $(date +"%Y-%m-%d %H:%M:%S.%N")"
  # time=msec, lat=nsec
  sudo fio --ioengine=libaio --filename=$DEV --name=test --rw=read --iodepth=1 --bs=4KB --runtime=$RUNTIME  \
  --log_avg_msec=1 --write_lat_log=${BLKTRACE_RESULT_PATH}/lat.log --write_bw_log=${BLKTRACE_RESULT_PATH}/bw.log >/dev/null &

  # window check
  while [ 1 -eq 1 ]; do
    window=$(sudo nvme get-feature $DEV -n 1 -f 20 -c 1 | tail -c 2)

    echo $window

    if [ $window == "2" ]; then
        sudo nvme admin-passthru $DEV -n 0x1 -o 0x09 -w --cdw10=0x14 --cdw11=0x01 --cdw12=0x01
        date +"%Y-%m-%d %H:%M:%S.%N" >> $WINDOW_LOG
    fi

    sleep 0.01
  done




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
