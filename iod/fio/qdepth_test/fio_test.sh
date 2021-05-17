#!/bin/bash
CHARACTER="/dev/nvme1"
NAMESPACE=1
FIO_RESULT_PATH="/home/data/iod/fio_result"
DTWIN_FIO_PATH="/home/hkchoi/Downloads/dtwin-fio"
DEFAULT_FIO_PATH="/home/hkchoi/Downloads/fio"
IO_TYPE="randrw"
MIN_BS=12   # 2^12 = 4KB
MAX_BS=16   # 2^16 = 64KB
MIN_DEPTH=0 # 2^0 = 1
MAX_DEPTH=6 # 2^6 = 64
MIN_RATIO=1 # 1*25 = 25%
MAX_RATIO=3 # 25*3 = 75%
RUNTIME=60
RAMPTIME=0
DEVICE=$CHARACTER"n"$NAMESPACE

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

        ${1}/fio --direct=1 --ioengine=libaio --iodepth=$IODEPTH --filename=$DEVICE --name=test --rw=$IO_TYPE --rwmixread=$RATIO --bs=$BS --time_based --runtime=$RUNTIME \
          --ramp_time=$RAMPTIME --percentile_list=99:99.9:99.99:99.999:99.9999:100 --output=${FIO_RESULT_PATH}/${IO_TYPE}_${IODEPTH}_${BS}_${RATIO}_${2}.txt \
          >/dev/null
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
}

main $1
