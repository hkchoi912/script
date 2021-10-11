#!/bin/bash

# if [ $(id -u) -ne 0 ]
# then
#   echo "Requires root privileges"
#   exit 1
# fi

cnt=0

# device
CHARACTER="nvme1"
NAMESPACE=2
DEV_NAME=$CHARACTER"n"$NAMESPACE"p1"
DEV=/dev/$DEV_NAME

# blktrace
BLKTRACE_RESULT_PATH="/home/data/iod/DB-data/output/dbbench/"
RUNTIME=1200 # sec

# window
WINDOW_LOG=${BLKTRACE_RESULT_PATH}/window.log

#rocksdb
ROCKSDB_PATH="/home/hkchoi/research/iod/benchmark/rocksdb"
MOUNT_PATH="/home/iod/NVMset${NAMESPACE}"
DB_PATH="${MOUNT_PATH}/KV_DB"
WAL_PATH="/home/iod/NVMset4"

# blkparse
BLKPARSE_OUTPUT=${BLKTRACE_RESULT_PATH}/dbbench_blkparse

# D2C extractor
D2C_extractor_PATH="/home/hkchoi/research/script/iod/D2C_extractor"
D2C_READ_OUTPUT=${BLKTRACE_RESULT_PATH}/dbbench_d2c_read
D2C_WRITE_OUTPUT=${BLKTRACE_RESULT_PATH}/dbbench_d2c_write

main() {
  sudo mount $DEV ${MOUNT_PATH}
  sudo mount /dev/nvme1n4p1 ${WAL_PATH}

  if [ ! -d ${BLKTRACE_RESULT_PATH} ]; then
    mkdir -p ${BLKTRACE_RESULT_PATH}
  fi

  sudo chown hkchoi:hkchoi -R /home/iod

  rm -rf $WINDOW_LOG
  touch $WINDOW_LOG
  rm -rf ${BLKTRACE_RESULT_PATH}/nvme*

  if [ $# -ne 1 ]; then
    echo $#
    echo "Need to make initial DB? no=0, yes=1"
    kill -15 $$
  elif [ $1 -eq "1" ]; then
    sudo rm -rf ${DB_PATH}/*

    ${ROCKSDB_PATH}/db_bench –benchmarks=fillrandom –perf_level=3 \
      -use_direct_io_for_flush_and_compaction=true -use_direct_reads=true -cache_size=268435456 \
      -key_size=48 -value_size=43 -num=50000000 -db=${DB_PATH}
  fi

  sleep 5

  sync
  echo "  Flushing..."
  sudo nvme flush $DEV -n $NAMESPACE

  sleep 5

  # set PLM
  sudo nvme admin-passthru /dev/nvme1 -n 0x1 -o 0x09 -w --cdw10=0x13 --cdw11=0x0${NAMESPACE} --cdw12=0x01

  echo "  blktrace start...   $(date)" >> $WINDOW_LOG
  sudo blktrace -d $DEV -w $RUNTIME -D ${BLKTRACE_RESULT_PATH} >/dev/null &

  # set DTWIN
  sudo nvme admin-passthru /dev/nvme1 -n 0x1 -o 0x09 -w --cdw10=0x14 --cdw11=0x${NAMESPACE} --cdw12=0x01
  sleep 0.02

  # zippydb tracing
  # -wal_bytes_per_sync=1
  # -max_write_batch_group_size_bytes=1
  # -enable_pipelined_write=false
  ${ROCKSDB_PATH}/db_bench -benchmarks="mixgraph" -use_direct_io_for_flush_and_compaction=true -use_direct_reads=true -cache_size=268435456 \
    -key_dist_a=0.002312 -key_dist_b=0.3467 -keyrange_dist_a=14.18 -keyrange_dist_b=-2.917 -keyrange_dist_c=0.0164 -keyrange_dist_d=-0.08082 \
    -keyrange_num=30 -value_k=0.2615 -value_sigma=25.45 -iter_k=2.517 -iter_sigma=14.236 -mix_get_ratio=0.83 -mix_put_ratio=0.14 -mix_seek_ratio=0.03 \
    -sine_mix_rate_interval_milliseconds=5000 -sine_a=1000 -sine_b=0.000073 -sine_d=4500 –perf_level=2 -reads=420000000 -num=50000000 -key_size=48 \
    -db=${DB_PATH} -use_existing_db=true &

  # window check
  while [ $cnt != $RUNTIME ]; do
    window=$(sudo nvme get-feature /dev/nvme1 -n 0x1 -f 20 -c ${NAMESPACE} | tail -c 2)

    if [ $window != "1" ]; then
      sudo nvme admin-passthru /dev/nvme1 -n 0x1 -o 0x09 -w --cdw10=0x14 --cdw11=0x${NAMESPACE} --cdw12=0x01
      date +"%H:%M:%S.%N" >> $WINDOW_LOG
    fi

    sleep 1
    cnt=$(($cnt+1))
  done

  echo "  blktrace end..."
  sudo pkill -15 db_bench
  sudo pkill -15 blktrace

  echo "  blkparse start...   $(date)"
  blkparse -i ${BLKTRACE_RESULT_PATH}/$DEV_NAME -o ${BLKPARSE_OUTPUT} >/dev/null

  rm -rf ${BLKTRACE_RESULT_PATH}/nvme*

  echo "  save rocksDB LOG..."
  cp ${DB_PATH}/LOG ${BLKTRACE_RESULT_PATH}

  echo "  D2C extractor start...   $(date)"
  ${D2C_extractor_PATH}/D2C_extractor ${BLKPARSE_OUTPUT} ${D2C_READ_OUTPUT} ${D2C_WRITE_OUTPUT}

}

main $1
