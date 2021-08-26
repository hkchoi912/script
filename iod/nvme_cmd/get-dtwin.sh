#!/bin/bash

#for i in $(seq 1 1000); do
#    sudo nvme get-feature /dev/nvme1n1 -n 1 -f 20 -c 1
#    sleep 1
#done

while [ 1 -eq 1 ]; do
    window=$(sudo nvme get-feature /dev/nvme1n1 -n 1 -f 20 -c 1 | tail -c 2)
    # sudo nvme get-feature /dev/nvme1n1 -n 1 -f 20 -c 1 | tail -c 2
    # sudo nvme get-feature /dev/nvme1n2 -n 2 -f 20 -c 1
    # sudo nvme get-feature /dev/nvme1n3 -n 3 -f 20 -c 1
    # sudo nvme get-feature /dev/nvme1n4 -n 4 -f 20 -c 1
    # date

    echo $window

    if [ $window == "2" ]; then
        echo "NDWIN"
        # sudo nvme admin-passthru /dev/nvme1 -n 0x1 -o 0x09 -w --cdw10=0x14 --cdw11=0x01 --cdw12=0x01
        # date
    fi

    sleep 0.01
done
