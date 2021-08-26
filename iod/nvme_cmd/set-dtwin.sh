#!/bin/bash

#for i in $(seq 1 1000); do
#    sudo nvme get-feature /dev/nvme1n1 -n 1 -f 20 -c 1
#    sleep 1
#done

while [ 1 -eq 1 ]; do
    sudo nvme set-feature /dev/nvme1n1 -n 1 -f 20 -c 1 -v 1
    # sudo nvme get-feature /dev/nvme1n2 -n 2 -f 20 -c 1
    # sudo nvme get-feature /dev/nvme1n3 -n 3 -f 20 -c 1
    # sudo nvme get-feature /dev/nvme1n4 -n 4 -f 20 -c 1
    sleep 1
done
