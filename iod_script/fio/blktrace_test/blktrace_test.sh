#!/bin/bash
CHARACTER="/dev/nvme1"
NAMESPACE=1
FIO_RESULT_PATH="/home/data/iod/fio_result"
BLKTRACE_RESULT_PATH="/home/data/iod/blktrace"
BLKPARSE_RESULT_PATH="/home/data/iod/blktrace/formatted"
DTWIN_FIO_PATH="/home/hkchoi/Downloads/dtwin-fio"
DEFAULT_FIO_PATH="/home/hkchoi/Downloads/fio"
PARSING_SCRIPT_PATH="/home/hkchoi/script/iod/fio/parsing"
PARSING_SCRIPT_NAME="trace_formatter_WAR.py"
PARSING_SCRIPT_ARG="trace_formatter_config.yaml"
IO_TYPE="randrw"
MIN_BS=12   # 2^12 = 4KB
MAX_BS=12   # 2^16 = 64KB
MIN_DEPTH=3 # 2^0 = 1
MAX_DEPTH=3 # 2^6 = 64
MIN_RATIO=2 # 1*25 = 25%
MAX_RATIO=2 # 25*3 = 75%
RUNTIME=120
RAMPTIME=0
DEVICE=$CHARACTER"n"$NAMESPACE

pid_kills() {
  PIDS=("${!1}")
  for pid in "${PIDS[*]}"; do
    kill -15 $pid
  done
}

# -d=device, -w=second, -D=output dir
blktrace_start() {
  if [ ! -d $BLKTRACE_RESULT_PATH ]; then
    mkdir -p $BLKTRACE_RESULT_PATH
  fi
  BLKTRACE_PIDS=()
  blktrace -d $DEVICE -w ${RUNTIME} -D ${BLKTRACE_RESULT_PATH} >/dev/null &
  BLKTRACE_PIDS+=("$!")
}

blktrace_end() {
  pid_kills BLKTRACE_PIDS[@]
  sleep 5
}

# $1=ndwin / dtwin
blkparse_do() {
  blkparse -i ${BLKTRACE_RESULT_PATH}/nvme1n1 -o ${BLKTRACE_RESULT_PATH}/${IO_TYPE}_${IODEPTH}_${BS}_${RATIO}_${1}.txt >/dev/null
  rm $BLKTRACE_RESULT_PATH/nvme1n1*
}

# $1=fio path. $2="ndwin" or "dtwin"
fio_do() {
  if [ ! -d $FIO_RESULT_PATH ]; then
    mkdir -p $FIO_RESULT_PATH
  fi

  for qorder in $(seq $MIN_DEPTH $MAX_DEPTH); do
    IODEPTH=$(seq -f "%03g" $((2 ** $qorder)) $((2 ** $qorder)))

    for bsorder in $(seq $MIN_BS $MAX_BS); do
      BS=$(seq -f "%03g" $((2 ** $bsorder / 1024)) $((2 ** $bsorder / 1024)))"K"

      for ratio_num in $(seq $MIN_RATIO $MAX_RATIO); do

        RATIO=$(seq -f "%03g" $((25 * $ratio_num)) $((25 * $ratio_num)))
        echo "  ${IO_TYPE} QD "${IODEPTH}" BS "${BS}" RATIO "${RATIO}"% ${2}"
        echo "  Flushing..."

        nvme flush $DEVICE -n $NAMESPACE

        echo "  PLM off before start FIO..."
        nvme set-feature ${DEVICE} -f 20 -c 1 -v 2 >/dev/null
        nvme set-feature ${DEVICE} -f 19 -v 1 >/dev/null

        echo "  blktrace start..."
        blktrace_start

        ${1}/fio --direct=1 --ioengine=libaio --iodepth=$IODEPTH --filename=$DEVICE --name=test --rw=$IO_TYPE --rwmixread=$RATIO --bs=$BS --time_based --runtime=$RUNTIME \
          --ramp_time=$RAMPTIME --percentile_list=99:99.9:99.99:99.999:99.9999:100 --output=${FIO_RESULT_PATH}/${IO_TYPE}_${IODEPTH}_${BS}_${RATIO}_${2}.txt \
          >/dev/null

        echo "  blktrace end..."
        blktrace_end

        echo "  blkparse do..."
        blkparse_do ${2}
      done
    done
  done

  echo "Fio done"
}

# $1= 1(ndwin) 2(dtwin) 3(both)
main() {
  if [ $# -ne 1 ]; then
    echo "Need argument: 1=Default fio  2=DTWIN fio  3=Both"
    kill -15 $$
  elif [ $1 -eq "1" ]; then
    fio_do ${DEFAULT_FIO_PATH} "ndwin"
  elif [ $1 -eq "2" ]; then
    fio_do ${DTWIN_FIO_PATH} "dtwin"
  elif [ $1 -eq "3" ]; then
    fio_do ${DEFAULT_FIO_PATH} "ndwin"
    sleep 5
    fio_do ${DTWIN_FIO_PATH} "dtwin"
  else
    echo "Need argument: 1=Default fio  2=DTWIN fio  3=Both"
    kill -15 $$
  fi

  sleep 5
  echo "  start parsing..."
  python ${PARSING_SCRIPT_PATH}/${PARSING_SCRIPT_NAME} ${PARSING_SCRIPT_PATH}/${PARSING_SCRIPT_ARG}
  echo "  parsing done..."
  chown hkchoi:hkchoi /home/data/iod/blktrace -R
}

main $1
