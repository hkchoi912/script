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
PARSING_SCRIPT_ARG="trace_formatter_config.yaml"
MIN_DEPTH=0 # 2^0 = 1
MAX_DEPTH=0 # 2^6 = 64
RUNTIME=30

​ftraceEnable() {
    #sh -c "echo 'kmem:*' > /sys/kernel/debug/tracing/set_event"
    echo 'syscalls:sys_enter_ioctl' > /sys/kernel/debug/tracing/set_event
    echo 'syscalls:sys_exit_ioctl' >> /sys/kernel/debug/tracing/set_event
    echo 'nvme:*' >> /sys/kernel/debug/tracing/set_event
    
    #echo 'function_graph' > /sys/kernel/debug/tracing/current_tracer
}
​
ftraceStart() {
    echo '1' > /sys/kernel/debug/tracing/tracing_on
}
​
ftraceEnd() {
    echo '0' > /sys/kernel/debug/tracing/tracing_on
    cp /sys/kernel/debug/tracing/trace trace
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
      #            sudo nvme format $DEVICE -s 1 -f

      if [ $2 == 'dtwin' ]; then
        echo "  Wait for back to ndwin"
        sleep 60
      fi

      #echo "  Filling...480G for overprovisioning"
      #            sudo fio --ioengine=libaio --iodepth=1 --filename=$DEVICE --name=test --rw=write --bs=1MB --fill_device=1 >/dev/null

      echo "  Flushing..."
      sudo nvme flush $DEVICE -n $NAMESPACE

      echo "  ftraceStart start..."
      ​ftraceEnable
      ftraceStart
      
      #--log_avg_msec=$LOG_AVG \
      sudo ${1}/fio --direct=1 --ioengine=libaio --filename=$DEVICE --name=test --read_iolog=$FILE --iodepth=$IODEPTH --bs=${BS} \
        --write_lat_log=${RESULT_LOG_PATH}/${2}_${IODEPTH}_$(basename $FILE) \
        >/dev/null

      echo "  ftraceEnd end..."
      ftraceEnd
      

      #echo "  Delete clat & slat log..."
      sudo rm -rf ${RESULT_LOG_PATH}/${2}_${IODEPTH}_$(basename $FILE)_clat.1.log
      sudo rm -rf ${RESULT_LOG_PATH}/${2}_${IODEPTH}_$(basename $FILE)_slat.1.log

      sudo sed -rn 's/([0-9]+), ([0-9]+), [0-9]+, [0-9]+, [0-9]+/\1 \2/p' ${RESULT_LOG_PATH}/${2}_${IODEPTH}_$(basename $FILE)_lat.1.log >${PARSING_FILE}_parsing
      sudo sed -rn 's/([0-9]+), ([0-9]+), 0, [0-9]+, [0-9]+/\1 \2/p' ${RESULT_LOG_PATH}/${2}_${IODEPTH}_$(basename $FILE)_lat.1.log >${PARSING_FILE}_onlyread_parsing

    done
  done
}

# $1= 0(off) 1(ndwin) 2(dtwin) 3(both)
main() {

  if [ $# -ne 1 ]; then
    echo "Need argument:  1=NDWIN  2=DTWIN  3=Both "
    sudo kill -15 $$
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
    sudo kill -15 $$
  fi

  sudo chown hkchoi:hkchoi -R /home/data/iod/replay
}

main $1
