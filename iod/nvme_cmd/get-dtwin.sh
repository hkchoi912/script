#!/bin/bash

#for i in $(seq 1 1000); do
#    sudo nvme get-feature /dev/nvme1n1 -n 1 -f 20 -c 1
#    sleep 1
#done

# window check
  while [ 1 -eq 1 ]; do
    sudo nvme admin-passthru /dev/nvme1 -n 0x1 -o 0x0a -r --cdw10=0x14 --cdw11=0x01

    # window=$(sudo nvme admin-passthru /dev/nvme1 -n 0x1 -o 0x0a -r --cdw10=0x14 --cdw11=0x04 | tail -c 2)

    # if [ $window != "1" ]; then
    #   sudo nvme admin-passthru /dev/nvme1 -n 0x1 -o 0x09 -w --cdw10=0x13 --cdw11=0x04 --cdw12=0x02

    #   sleep 4

    #   sudo nvme admin-passthru /dev/nvme1 -n 0x1 -o 0x09 -w --cdw10=0x13 --cdw11=0x04 --cdw12=0x01
    #   sudo nvme admin-passthru /dev/nvme1 -n 0x1 -o 0x09 -w --cdw10=0x14 --cdw11=0x04 --cdw12=0x01

    #   date +"%H:%M:%S.%N"
    # fi

    sleep 1
  done
