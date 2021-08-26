#!/bin/bash

while [ 1 -eq 1 ]; do
    window=$(sudo nvme get-feature /dev/nvme1n1 -n 1 -f 20 -c 1 | tail -c 2)

    echo $window

    if [ window=='2' ]; then
      sudo nvme admin-passthru /dev/nvme1 -n 1 -o 0x09 -w --cdw10=0x13 --cdw11=0x01 --cdw12=0x01
      date
    fi

    sleep 1
done
