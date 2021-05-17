#!/bin/bash

MIN_SIZE=6 #40*2^0 = 40MB
MAX_SIZE=6 #40*2^7 = 5.12GB
TYPE="read"
BS='004KB'

#--time_based --runtime=3 \
for i in $(seq $MIN_SIZE $MAX_SIZE); do
    SIZE=$(seq -f "%04g" $((40 * (2 ** $i))) $((40 * (2 ** $i))))

    FILE_NAME="/home/data/iod/replay/io_log/${BS}_${TYPE}_${SIZE}MB.log"
    rm -rf $FILE_NAME
    #--size=${SIZE}MB
    fio --direct=1 --ioengine=libaio --filename=/dev/nvme1n1 --bs=${BS} --iodepth=1 --rw=${TYPE} --name=test \
        --size=${SIZE}MB \
        --write_iolog=$FILE_NAME >/dev/null
done

chown hkchoi:hkchoi -R .
