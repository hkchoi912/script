#!/bin/bash
PARM="/home/hkchoi/script/trace/myfio.fio"
OUTPUT_DIR1="/home/hkchoi/data/blktrace/test1"

pid_kills() {
    PIDS=("${!1}")
    for pid in "${PIDS[*]}"; do
        kill -15 $pid
    done
}
# -d=device, -w=time, -D=output dir 
blktrace_start() {
    BLKTRACE_PIDS=() #????
    blktrace -d /dev/nvme1n1 -w 180 -D ${OUTPUT_DIR1} & BLKTRACE_PIDS+=("$!")  #????
}

blktrace_end() {
    pid_kills BLKTRACE_PIDS[@] 
    sleep 5
}

blktrace_start
#<program>
fio $PARM
#fio --directory=/home/hkchoi/iod-data/nvme1n1/fio --name fio_test_file --direct=1 --rw=randread --bs=4K --size=1G --numjobs=8 --time_based --runtime=180 --group_reporting --norandommap
blktrace_end