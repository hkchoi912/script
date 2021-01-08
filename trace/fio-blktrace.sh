#!/bin/bash
PARM="/home/hkchoi/script/trace/myfio.fio"
OUTPUT_DIR1="/home/data/blktrace/test1"
IODEPTH=6 # 2^6 = 64
DEVICE=/dev/nvme1n1
BS=4096
RUNTIME=60
RAMPTIME=0

pid_kills() {
    PIDS=("${!1}")
    for pid in "${PIDS[*]}"; do
        kill -15 $pid
    done
}
# -d=device, -w=time, -D=output dir 
blktrace_start() {
    BLKTRACE_PIDS=() #????
    blktrace -d /dev/nvme1n1 -w 30 -D ${OUTPUT_DIR1} & BLKTRACE_PIDS+=("$!")  #????
}

blktrace_end() {
    pid_kills BLKTRACE_PIDS[@] 
    sleep 5
}

main() {
blktrace_start
#<program>
#fio $PARM
#log_avg-msec=10
#write_iolog=randread.log
#write_lat_log=randread
#$(($BS/1024))K_$IODEPTH
fio --direct=1 --ioengine=libaio --iodepth=$((2**$IODEPTH)) --filename=$DEVICE --name=test --rw=randread --bs=$BS --time_based --runtime=$RUNTIME \
--ramp_time=$RAMPTIME --percentile_list=99:99.9:99.99:99.999:99.9999:100 --log_avg-msec=10 --write_lat_log=randread_$(($BS/1024))K_$IODEPTH --output=randread_$(($BS/1024))K_$IODEPTH.txt > /dev/null

blktrace_end
}

main