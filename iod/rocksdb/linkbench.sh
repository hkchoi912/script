#!/bin/bash

if [ $(id -u) -ne 0 ]
then
  echo "Requires root privileges"
  exit 1
fi

# device
CHARACTER="nvme1"
NAMESPACE=1
DEV_NAME=$CHARACTER"n"$NAMESPACE
DEV=/dev/$DEV_NAME

# root path
ROOT_PATH=/home/hkchoi/data/linkbench

# blktrace
BLKTRACE_RESULT_PATH="$ROOT_PATH/blktrace"
RUNTIME=10800 # sec

# blkparse
BLKPARSE_OUTPUT=${BLKTRACE_RESULT_PATH}/linkbench-output

# linkbench
LINKBENCH_PATH="/root/workspace/linkbench"

# D2C extractor
D2C_extractor_PATH="/root/workspace/script/iod/D2C_extractor"
D2C_READ_OUTPUT=${BLKTRACE_RESULT_PATH}/linkbench-output-read
D2C_WRITE_OUTPUT=${BLKTRACE_RESULT_PATH}/linkbench-output-write

main() {
  # if [ $# -ne 1 ]; then
  #   echo $#
  #   echo "Need to loading data? no=0, yes=1"
  #   kill -15 $$
  # elif [ $1 -eq "1" ]; then
  #   echo "  loding linkbench...   $(date)"
  #   ${LINKBENCH_PATH}/bin/linkbench -c config/MyConfig.properties -l
  # fi

  if [ ! -d ${BLKTRACE_RESULT_PATH} ]; then
    mkdir -p ${BLKTRACE_RESULT_PATH}
  fi

  rm -rf ${BLKTRACE_RESULT_PATH}/nvme*

  echo "  blktrace start...   $(date)"
  blktrace -d $DEV -w $RUNTIME -D ${BLKTRACE_RESULT_PATH} >/dev/null

  # echo "  linkbench start...   $(date)"
  # ${LINKBENCH_PATH}/bin/linkbench -c ${LINKBENCH_PATH}/config/MyConfig.properties -r

  # kill blktrace
  pkill -15 blktrace

  echo "  blkparse start...   $(date)"
  blkparse ${BLKTRACE_RESULT_PATH}/${DEV_NAME} -o ${BLKPARSE_OUTPUT} > /dev/null

  echo "  D2C extractor start...   $(date)"
  ${D2C_extractor_PATH}/D2C_extractor ${BLKPARSE_OUTPUT} ${D2C_READ_OUTPUT} ${D2C_WRITE_OUTPUT}

  rm -rf ${BLKTRACE_RESULT_PATH}/nvme*
}

main $1
