#!/bin/bash
CHARACTER="/dev/nvme1"
NAMESPACE=1
DEVICE=$CHARACTER"n"$NAMESPACE
BLKTRACE_RESULT_PATH="/home/data/iod/replay/blktrace"
BLKPARSE_RESULT_PATH="/home/data/iod/replay/blktrace/formatted"

FIO_RESULT_PATH="/home/data/iod/replay/fio_result"
SOURCE_FILE_PATH="/home/data/iod/replay/io_log"
RESULT_LOG_PATH="/home/data/iod/replay/result_log"
PARSING_FILE_PATH="/home/data/iod/replay/parsing"
DEFAULT_FIO_PATH="/home/hkchoi/Downloads/fio"
NDWIN_FIO_PATH="/home/hkchoi/Downloads/ndwin-fio"
DTWIN_FIO_PATH="/home/hkchoi/Downloads/dtwin-war-fio"
PARSING_SCRIPT_PATH="/home/hkchoi/script/iod/fio/parsing"
PARSING_SCRIPT_NAME="trace_formatter_WAR.py"
PARSING_SCRIPT_ARG="trace_formatter_config_fio.yaml"
MIN_DEPTH=6 # 2^0 = 1
MAX_DEPTH=6 # 2^6 = 64
RUNTIME=30

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
  blkparse -i ${BLKTRACE_RESULT_PATH}/nvme1n1 -o ${BLKTRACE_RESULT_PATH}/${1}_${IODEPTH}_$(basename $FILE) >/dev/null
  rm -rf $BLKTRACE_RESULT_PATH/nvme1n1*
}

fio_do() {
  for FILE in $SOURCE_FILE_PATH/*.log; do
    for qorder in $(seq $MIN_DEPTH $MAX_DEPTH); do
      IODEPTH=$(seq -f "%03g" $((2 ** $qorder)) $((2 ** $qorder)))

      BS=$(echo $(basename $FILE) | (sed -rn 's/(...KB)_.+/\1/p'))

      rm -rf $RESULT_LOG_PATH/${2}_${IODEPTH}_$(basename $FILE)_*
      PARSING_FILE=$PARSING_FILE_PATH/${2}_${IODEPTH}_$(basename $FILE)

      echo "  window:$2   iodepth:$IODEPTH   BS:$BS   FILE=$(basename $FILE) "
      #echo "  Formatting..."
      #            nvme format $DEVICE -s 1 -f

      if [ $2 == 'dtwin' ]; then
        echo "  Wait for back to ndwin"
        sleep 60
      fi

      #echo "  Filling...480G for overprovisioning"
      #            fio --ioengine=libaio --iodepth=1 --filename=$DEVICE --name=test --rw=write --bs=1MB --fill_device=1 >/dev/null

      echo "  Flushing..."
      nvme flush $DEVICE -n $NAMESPACE

      echo "  blktrace start..."
      blktrace_start

      #--log_avg_msec=$LOG_AVG \
      ${1}/fio --direct=1 --ioengine=libaio --filename=$DEVICE --name=test --read_iolog=$FILE --iodepth=$IODEPTH --bs=${BS} \
        --write_lat_log=${RESULT_LOG_PATH}/${2}_${IODEPTH}_$(basename $FILE) \
        >/dev/null

      echo "  blktrace end..."
      blktrace_end

      echo "  blkparse do..."
      blkparse_do ${2}

      #echo "  Delete clat & slat log..."
      rm -rf ${RESULT_LOG_PATH}/${2}_${IODEPTH}_$(basename $FILE)_clat.1.log
      rm -rf ${RESULT_LOG_PATH}/${2}_${IODEPTH}_$(basename $FILE)_slat.1.log

      sed -rn 's/([0-9]+), ([0-9]+), [0-9]+, [0-9]+, [0-9]+/\1 \2/p' ${RESULT_LOG_PATH}/${2}_${IODEPTH}_$(basename $FILE)_lat.1.log >${PARSING_FILE}_parsing
      sed -rn 's/([0-9]+), ([0-9]+), 0, [0-9]+, [0-9]+/\1 \2/p' ${RESULT_LOG_PATH}/${2}_${IODEPTH}_$(basename $FILE)_lat.1.log >${PARSING_FILE}_onlyread_parsing

    done
  done
}

# $1= 0(off) 1(ndwin) 2(dtwin) 3(both)
main() {

  if [ $# -ne 1 ]; then
    echo "Need argument:  1=NDWIN  2=DTWIN  3=Both "
    kill -15 $$
  elif [ $1 -eq "1" ]; then
    fio_do ${NDWIN_FIO_PATH} "ndwin"
  elif [ $1 -eq "2" ]; then
    fio_do ${DTWIN_FIO_PATH} "dtwin"
  elif [ $1 -eq "3" ]; then
    fio_do ${NDWIN_FIO_PATH} "ndwin"
    sleep 5
    fio_do ${DTWIN_FIO_PATH} "dtwin"
  else
    echo "Need argument: 0=Default  1=NDWIN  2=DTWIN  3=Both "
    kill -15 $$
  fi

  workon python3
  sleep 5
  echo "  start parsing..."
  python ${PARSING_SCRIPT_PATH}/${PARSING_SCRIPT_NAME} ${PARSING_SCRIPT_PATH}/${PARSING_SCRIPT_ARG}
  echo "  parsing done..."
  chown hkchoi:hkchoi -R /home/data/iod/replay
  deactivate
}

main $1
