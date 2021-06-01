#!/bin/bash

#for i in $(seq 1 1000); do
#    sudo nvme get-feature /dev/nvme1n1 -n 1 -f 20 -c 1
#    sleep 1
#done

while [ 1 -eq 1 ]; do
    sudo nvme get-feature /dev/nvme2n1 -n 1 -f 20 -c 1
    sleep 0.1
done
