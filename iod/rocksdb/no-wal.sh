#!/bin/bash
# device
CHARACTER="nvme1"
NAMESPACE=1
DEV_NAME=$CHARACTER"n"$NAMESPACE"p1"
DEV=/dev/$DEV_NAME

# blktrace
BLKTRACE_RESULT_PATH="/home/data/iod/DB-data/output/dbbench/"
RUNTIME=1200 # sec

#rocksdb
ROCKSDB_PATH="/home/hkchoi/research/iod/benchmark/rocksdb"
MOUNT_PATH="/home/iod/NVMset${NAMESPACE}"
DB_PATH="${MOUNT_PATH}/KV_DB"
# DB_PATH="/home/data/983dct-non-iod/randomKV"
WAL_PATH="/home/iod/NVMset4"

# blkparse
BLKPARSE_OUTPUT=${BLKTRACE_RESULT_PATH}/dbbench_blkparse

# D2C extractor
D2C_extractor_PATH="/home/hkchoi/research/script/iod/D2C_extractor"
D2C_READ_OUTPUT=${BLKTRACE_RESULT_PATH}/dbbench_d2c_read
D2C_WRITE_OUTPUT=${BLKTRACE_RESULT_PATH}/dbbench_d2c_write

# cdf & tail latency
CDF_extractor="/home/hkchoi/research/script/iod/fio/cdf"
LAT_extractor="/home/hkchoi/research/script/iod/fio/cdf"

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

  sudo mount $DEV ${MOUNT_PATH}
  sudo mount /dev/nvme1n4p1 ${WAL_PATH}

  if [ ! -d ${BLKTRACE_RESULT_PATH} ]; then
    mkdir -p ${BLKTRACE_RESULT_PATH}
  fi

  sudo chown hkchoi:hkchoi -R /home/iod

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

  ROCKSDB_PIDS=()

  echo "  blktrace start...   $(date)"
  blktrace_start

  # zippydb tracing
  ${ROCKSDB_PATH}/db_bench -benchmarks="mixgraph" -use_direct_io_for_flush_and_compaction=true -use_direct_reads=true -cache_size=268435456 \
    -key_dist_a=0.002312 -key_dist_b=0.3467 -keyrange_dist_a=14.18 -keyrange_dist_b=-2.917 -keyrange_dist_c=0.0164 -keyrange_dist_d=-0.08082 \
    -keyrange_num=30 -value_k=0.2615 -value_sigma=25.45 -iter_k=2.517 -iter_sigma=14.236 -mix_get_ratio=0.83 -mix_put_ratio=0.14 -mix_seek_ratio=0.03 \
    -sine_mix_rate_interval_milliseconds=5000 -sine_a=1000 -sine_b=0.000073 -sine_d=4500 –perf_level=2 -reads=420000000 -num=50000000 -key_size=48 \
    -db=${DB_PATH} -use_existing_db=true \
    -wal_dir=${WAL_PATH} &

  ROCKSDB_PIDS+=("$!")

  sleep $RUNTIME

  pid_kills ROCKSDB_PIDS[@] >/dev/null

  echo "  blktrace end..."
  blktrace_end

  echo "  blkparse do..."
  blkparse -i ${BLKTRACE_RESULT_PATH}/$DEV_NAME -o ${BLKPARSE_OUTPUT} >/dev/null

  rm -rf ${BLKTRACE_RESULT_PATH}/nvme*

  echo "  save rocksDB LOG..."
  cp ${DB_PATH}/LOG ${BLKTRACE_RESULT_PATH}

  echo "  extract D2C time"
  ${D2C_extractor_PATH}/D2C_extractor ${BLKPARSE_OUTPUT} ${D2C_READ_OUTPUT} ${D2C_WRITE_OUTPUT}

}

main $1
