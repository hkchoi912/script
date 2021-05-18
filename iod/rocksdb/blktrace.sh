#!/bin/bash
#device
# CHARACTER="/dev/nvme1"
CHARACTER="/dev/nvme2"
NAMESPACE=1
DEVICE=$CHARACTER"n"$NAMESPACE

#blktrace
BLKTRACE_RESULT_PATH="/home/data/iod/DB-data"
RUNTIME=3600    # 1h

#rocksdb
ROCKSDB_PATH="/home/hkchoi/Downloads/iod/facebook/rocksdb"
# DB_PATH="/home/data/983dct-non-iod/randomKV"
DB_PATH="/home/data/983dct-iod/randomKV"

#parsing
PARSING_FILE_PATH="/home/data/iod/replay/parsing"
PARSING_SCRIPT_PATH="/home/hkchoi/script/iod/fio/parsing"
PARSING_SCRIPT_NAME="trace_formatter.py"
PARSING_SCRIPT_ARG="trace_formatter_config_db.yaml"

pid_kills() {
  PIDS=("${!1}")
  for pid in "${PIDS[*]}"; do
    sudo kill -15 $pid
  done
}

# -d=device, -w=second, -D=output dir
blktrace_start() {
  BLKTRACE_PIDS=()
  sudo blktrace -d $DEVICE -w $RUNTIME -D ${BLKTRACE_RESULT_PATH} >/dev/null &
  BLKTRACE_PIDS+=("$!")
}

blktrace_end() {
  pid_kills BLKTRACE_PIDS[@]
  sleep 5
}

# $1=ndwin / dtwin
blkparse_do() {
  sudo blkparse -i $BLKTRACE_RESULT_PATH/${DEVICE} -o $BLKTRACE_RESULT_PATH/output >/dev/null
  rm -rf $BLKTRACE_RESULT_PATH/${DEVICE}*
}

main() {
  if [ ! -d $DB_PATH ]; then
    mkdir -p $DB_PATH
  fi


  # if [ $# -ne 1 ]; then
  #   echo $#
  #   echo "Need to make initial DB? no=0, yes=1"
  #   kill -15 $$
  # elif [ $1 -eq "1" ]; then
  #   rm -rf ${DB_PATH}/*

  #   ${ROCKSDB_PATH}/db_bench –benchmarks=fillrandom –perf_level=3 \
  #     -use_direct_io_for_flush_and_compaction=true -use_direct_reads=true -cache_size=268435456 \
  #     -key_size=48 -value_size=43 -num=50000000 -db=${DB_PATH}
  # fi

  sleep 1
  # rm -rf /home/data/983dct-iod/test.0.0

  # sleep 1
  # fio --ioengine=libaio --iodepth=1 --name=/home/data/983dct-non-iod/test --rw=write --bs=1MB --size=1.7T
  # fio --ioengine=libaio --iodepth=1 --name=/home/data/983dct-iod/test --rw=write --bs=1MB --size=425G
  sleep 1

  echo "  blktrace start..."
  blktrace_start

  # zippydb tracing
  ${ROCKSDB_PATH}/db_bench -benchmarks="mixgraph" -use_direct_io_for_flush_and_compaction=true -use_direct_reads=true -cache_size=268435456 \
    -key_dist_a=0.002312 -key_dist_b=0.3467 -keyrange_dist_a=14.18 -keyrange_dist_b=-2.917 -keyrange_dist_c=0.0164 -keyrange_dist_d=-0.08082 \
    -keyrange_num=30 -value_k=0.2615 -value_sigma=25.45 -iter_k=2.517 -iter_sigma=14.236 -mix_get_ratio=0.83 -mix_put_ratio=0.14 -mix_seek_ratio=0.03 \
    -sine_mix_rate_interval_milliseconds=5000 -sine_a=1000 -sine_b=0.000073 -sine_d=4500 –perf_level=2 -reads=420000000 -num=50000000 -key_size=48 \
    -db=${DB_PATH} -use_existing_db=true

    echo "  blktrace end..."
  blktrace_end

  echo "  blkparse do..."
  # blkparse -i nvme2n1 -o output > /dev/null
  blkparse_do

  workon python3
  #python /home/hkchoi/script/iod/fio/parsing/trace_formatter.py /home/hkchoi/script/iod/fio/parsing/trace_formatter_config_db.yaml
  python $PARSING_SCRIPT_PATH/$PARSING_SCRIPT_NAME $PARSING_SCRIPT_PATH/$PARSING_SCRIPT_ARG
  deactivate
}

main $1
