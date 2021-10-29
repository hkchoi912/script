#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Need to window path"
  kill -15 $$
else
  sudo rm $1/window.log
  touch $1/window.log
fi

mkdir -p /root/result/output
date +"%H:%M:%S.%N" >>$1/window.log
start_time="$(date -u +%s)"
end_time="$(date -u +%s)"

# set PLM & DTWIN
for i in "2" "3" "4"; do
  sudo nvme admin-passthru /dev/nvme1 -n 1 -o 0x09 -w --cdw10=0x13 --cdw11=0x0$i --cdw12=0x01
  sudo nvme admin-passthru /dev/nvme1 -n 1 -o 0x09 -w --cdw10=0x14 --cdw11=0x0$i --cdw12=0x01
done

# window check
while [ 1 -eq 1 ]; do
  window1=$(sudo nvme admin-passthru /dev/nvme1 -n 0x1 -o 0x0a -r --cdw10=0x14 --cdw11=0x02 2>&1 >/dev/null | tail -c 2)
  window2=$(sudo nvme admin-passthru /dev/nvme1 -n 0x1 -o 0x0a -r --cdw10=0x14 --cdw11=0x03 2>&1 >/dev/null | tail -c 2)
  window3=$(sudo nvme admin-passthru /dev/nvme1 -n 0x1 -o 0x0a -r --cdw10=0x14 --cdw11=0x04 2>&1 >/dev/null | tail -c 2)

  if [ $window1 == "1" -a $window2 == "1" -a $window3 == "1" ]; then
    end_time="$(date -u +%s)"
    echo $(($end_time - $start_time)) 1 >>$1/window.log
  else
    end_time="$(date -u +%s)"
    echo $(($end_time - $start_time)) 0 >>$1/window.log

    if [ $window1 != "1" ]; then
      temp1=$(sudo nvme admin-passthru /dev/nvme1 -n 1 -o 0x09 -w --cdw10=0x14 --cdw11=0x02 --cdw12=0x01 2>&1 >/dev/null)
    fi

    if [ $window2 != "1" ]; then
      temp2=$(sudo nvme admin-passthru /dev/nvme1 -n 1 -o 0x09 -w --cdw10=0x14 --cdw11=0x03 --cdw12=0x01 2>&1 >/dev/null)
    fi

    if [ $window3 != "1" ]; then
      temp3=$(sudo nvme admin-passthru /dev/nvme1 -n 1 -o 0x09 -w --cdw10=0x14 --cdw11=0x04 --cdw12=0x01 2>&1 >/dev/null)
    fi
  fi

  sleep 0.5

done
