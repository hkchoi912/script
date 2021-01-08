#!/bin/bash
​
TRACING=/sys/kernel/debug/tracing
​
ftraceEnable() {
    #sh -c "echo 'kmem:*' > /sys/kernel/debug/tracing/set_event"
    echo 'syscalls:sys_enter_ioctl' > /sys/kernel/debug/tracing/set_event
    echo 'syscalls:sys_exit_ioctl' > /sys/kernel/debug/tracing/set_event
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
​
testWithFtrace() {
    #ftraceEnable
    ftraceStart
#    /home/hkchoi/Downloads/dtwin-war-fio/fio --direct=1 --ioengine=libaio --filename=/dev/nvme1n1 --bs=4096 --iodepth=1 --rw=read --name=test --size=40MB --write_iolog=1 # >/dev/null
    /home/hkchoi/Downloads/dtwin-war-fio/fio --direct=1 --ioengine=libaio --filename=/dev/nvme1n1 --name=test --read_iolog=/home/data/iod/replay/io_log/016KB_write_0320MB.log --iodepth=1 --bs=4096 \

    ftraceEnd
}

main() {
    testWithFtrace
}
​
main