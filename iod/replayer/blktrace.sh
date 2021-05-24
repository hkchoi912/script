#!/bin/bash
# device
CHARACTER="nvme2"
NAMESPACE=1
DEV_NAME=$CHARACTER"n"$NAMESPACE
DEV=/dev/$DEV_NAME

# blktrace
BLKTRACE_RESULT_PATH="/home/data/iod/DB-data"
RUNTIME=120 # sec

# blkparse
FIRST_BLKPARSE_OUTPUT=${BLKTRACE_RESULT_PATH}/dbbench_blkparse
SECOND_BLKPARSE_OUTPUT=${BLKTRACE_RESULT_PATH}/replayer_blkparse

# D extractor
D_extractor_PATH="/home/hkchoi/script/iod/D_extractor"
D_extractor_OUTPUT=${FIRST_BLKPARSE_OUTPUT}_d

# delay_write
INPUT=${D_extractor_OUTPUT}

# D2C extractor
D2C_extractor_PATH="/home/hkchoi/script/iod/D2C_extractor"
D2C_READ=${BLKTRACE_RESULT_PATH}/replayer_d2c_read
D2C_WRITE=${BLKTRACE_RESULT_PATH}/replayer_d2c_write

pid_kills() {
  PIDS=("${!1}")
  for pid in "${PIDS[*]}"; do
    sudo kill -15 $pid
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

  if [ ! -d ${BLKTRACE_RESULT_PATH} ]; then
    mkdir -p ${BLKTRACE_RESULT_PATH}
  fi

  # sleep 1
  # sync
  # echo "  Flushing..."
  # nvme flush $DEV -n $NAMESPACE

  # echo "  extract D "
  # $D_extractor_PATH/D_extractor ${FIRST_BLKPARSE_OUTPUT} ${D_extractor_OUTPUT}

  echo "  blktrace start..."
  blktrace_start

  # ./delay_write_replayer $DEV $INPUT
  ./replayer $DEV ${D_extractor_OUTPUT}

  echo "  blktrace end..."
  blktrace_end

  echo "  blkparse do..."
  blkparse -i ${BLKTRACE_RESULT_PATH}/$DEV_NAME -o ${SECOND_BLKPARSE_OUTPUT} >/dev/null

  rm -rf ${BLKTRACE_RESULT_PATH}/nvme*

  echo "  extract D2C time"
  ${D2C_extractor_PATH}/D2C_extractor ${SECOND_BLKPARSE_OUTPUT} ${D2C_READ} ${D2C_WRITE}
}

main $1
