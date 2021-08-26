#!/bin/bash

#for i in $(seq 1 1000); do
#    sudo nvme get-feature /dev/nvme1n1 -n 1 -f 20 -c 1
#    sleep 1
#done

while [ 1 -eq 1 ]; do
    sudo nvme get-feature /dev/nvme1n1 -n 1 -f 19 -c 1 | head -1
    date
    sleep 1
done
