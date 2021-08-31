#!/bin/bash
# device
CHARACTER="nvme0"
NAMESPACE=1
DEV_NAME=$CHARACTER"n"$NAMESPACE
DEV=/dev/$DEV_NAME

# blktrace
BLKTRACE_RESULT_PATH="/home/hkchoi/data/iod/DB-data/output/wrk/"
RUNTIME=300 # sec

#DeathStart
WRK_PATH="/home/hkchoi/research/iod/bench/DeathStarBench/socialNetwork/wrk2"
NUM_THREAD=2
NUM_CONNS=10
DURATION=${RUNTIME}
REQ_PER_SEC=4000



# blkparse
BLKPARSE_OUTPUT=${BLKTRACE_RESULT_PATH}/wrk_blkparse

# D extractor
D_extractor_PATH="/home/hkchoi/script/iod/D_extractor"
D_extractor_OUTPUT=${BLKPARSE_OUTPUT}_d

# Q extractor
Q_extractor_PATH="/home/hkchoi/script/iod/Q_extractor"
Q_extractor_OUTPUT=${BLKPARSE_OUTPUT}_q

# D2C extractor
D2C_extractor_PATH="/home/hkchoi/script/iod/D2C_extractor"
D2C_READ_OUTPUT=${BLKTRACE_RESULT_PATH}/wrk_d2c_read
D2C_WRITE_OUTPUT=${BLKTRACE_RESULT_PATH}/wrk_d2c_write

# cdf & tail latency
CDF_extractor="/home/hkchoi/script/iod/fio/cdf"
LAT_extractor="/home/hkchoi/script/iod/fio/cdf"

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

  sleep 1
  sync
  echo "  Flushing..."
  sudo nvme flush $DEV -n $NAMESPACE

  DEATH_STAR_PID=()

  echo "  blktrace start...   $(date)"
  blktrace_start


  ${WRK_PATH}/wrk -D exp -t ${NUM_THREAD} -c ${NUM_CONNS} -d ${DURATION} -L \
  -s ${WRK_PATH}/scripts/social-network/mixed-workload.lua http://localhost:8080/wrk2-api/home-timeline/read -R ${REQ_PER_SEC} &


  DEATH_STAR_PID+=("$!")

  sleep $RUNTIME

  pid_kills DEATH_STAR_PID[@] >/dev/null

  echo "  blktrace end..."
  blktrace_end

  echo "  blkparse do..."
  blkparse -i ${BLKTRACE_RESULT_PATH}/$DEV_NAME -o ${BLKPARSE_OUTPUT} >/dev/null

  rm -rf ${BLKTRACE_RESULT_PATH}/nvme*

  echo "  extract D "
  $D_extractor_PATH/D_extractor ${BLKPARSE_OUTPUT} ${D_extractor_OUTPUT}

  echo "  extract Q "
  $Q_extractor_PATH/Q_extractor ${BLKPARSE_OUTPUT} ${Q_extractor_OUTPUT}

  echo "  extract D2C time"
  ${D2C_extractor_PATH}/D2C_extractor ${BLKPARSE_OUTPUT} ${D2C_READ_OUTPUT} ${D2C_WRITE_OUTPUT}

  echo "  cdf & tail latency"
  python ${CDF_extractor}/cdf_extractor.py ${D2C_READ_OUTPUT}
  source ${LAT_extractor}/lat_extractor.sh ${D2C_READ_OUTPUT}_cdf
  python ${CDF_extractor}/cdf_extractor.py ${D2C_WRITE_OUTPUT}
  source ${LAT_extractor}/lat_extractor.sh ${D2C_WRITE_OUTPUT}_cdf
  # python ${CDF_extractor}/cdf_extractor.py /home/data/iod/DB-data/output/wrk-120min-iod/compaction_read_10min
  # source ${LAT_extractor}/lat_extractor.sh /home/data/iod/DB-data/output/wrk/compaction_read_cdf

}

main $1
