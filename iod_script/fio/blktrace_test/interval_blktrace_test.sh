#!/bin/bash
CHARACTER="/dev/nvme1"
NAMESPACE=1
FIO_RESULT_PATH="/home/data/iod/interval/fio_result"
DTWIN_FIO_PATH="/home/hkchoi/Downloads/dtwin-fio"
DEFAULT_FIO_PATH="/home/hkchoi/Downloads/fio"
IO_TYPE="randrw"
MIN_BS=12   # 2^12 = 4KB
MAX_BS=12   # 2^16 = 64KB
MIN_DEPTH=3 # 2^0 = 1
MAX_DEPTH=3 # 2^6 = 64
MIN_RATIO=2 # 1*25 = 25%
MAX_RATIO=2 # 25*3 = 75%
RUNTIME=30
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

        nvme flush /dev/nvme1n1 -n $NAMESPACE
        nvme flush /dev/nvme1n2 -n $NAMESPACE
        nvme flush /dev/nvme1n3 -n $NAMESPACE
        nvme flush /dev/nvme1n4 -n $NAMESPACE

        echo "  PLM off before start FIO..."
        nvme set-feature ${DEVICE} -f 20 -c 1 -v 2 >/dev/null
        nvme set-feature ${DEVICE} -f 19 -v 1 >/dev/null

        #${1}/fio aio_job.fio >/dev/null$
        #fio test1.fio > /dev/null & fio test2.fio > /dev/null & fio test3.fio > /dev/null & fio test4.fio > /dev/null
        #fio test1.fio > /dev/null & /home/hkchoi/Downloads/ndwin-fio/fio test2.fio > /dev/null & fio test3.fio > /dev/null & fio test4.fio > /dev/null
        fio test1.fio > /dev/null & /home/hkchoi/Downloads/dtwin-fio/fio test2.fio > /dev/null & fio test3.fio > /dev/null & fio test4.fio > /dev/null
        
        #fio test1.fio > /dev/null & fio test2.fio > /dev/null
        #fio test1.fio > /dev/null & /home/hkchoi/Downloads/ndwin-fio/fio test2.fio > /dev/null
        #fio test1.fio > /dev/null & /home/hkchoi/Downloads/dtwin-fio/fio test2.fio > /dev/null
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

  chown hkchoi:hkchoi /home/data/iod/interval -R
}

main $1
