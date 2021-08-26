#!/bin/bash

# set-feature cmd
# [-o: set-feature opcode]. [-cdw10: PLM window feature]. [-cdw11: NVM set]. [cdw12: WINDOW set]
sudo nvme admin-passthru -o 9 -n 1 -w --cdw10=0x14 --cdw11=0x01 --cdw12=0x01 -s -d /dev/nvme1n1
# nvme set-feature /dev/nvme1n1 -f 19 -c 1 -v 1
# nvme get-feature /dev/nvme1n1 -f 19 -l 512 -c 1

# set-feature cmd
# [-o: get-feature opcode]. [-cdw10: PLM window feature]. [-cdw11: NVM set]
sudo nvme admin-passthru -o 10 -n 1 -r --cdw10=0x14 --cdw11=0x01 -s -d /dev/nvme1n1
# nvme set-feature /dev/nvme1n1 -f 20 -c 1 -v 1
# nvme get-feature /dev/nvme1n1 -f 20 -l 512 -c 1

nvme create-ns /dev/nvme1n1 -nsze 11995709440 -ncap 1199570940 -flbas 0 -dps 0 -nmic 0
