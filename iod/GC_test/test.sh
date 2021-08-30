#!/bin/bash

cnt=0
echo $cnt

while [ $cnt != 5 ]; do
    # window=$(nvme admin-passthru /dev/nvme1 -n 0x1 -o 0x0a -r --cdw10=0x14 --cdw11=0x04 | tail -c 2)

    # if [ $window != "1" ]; then

    #   nvme admin-passthru /dev/nvme1 -n 0x1 -o 0x09 -w --cdw10=0x14 --cdw11=0x04 --cdw12=0x01

    #   date +"%H:%M:%S.%N" >> $WINDOW_LOG
    # fi

    sleep 1
    echo $cnt
    cnt=$(($cnt+1))
done
