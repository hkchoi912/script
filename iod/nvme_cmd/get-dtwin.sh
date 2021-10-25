#!/bin/bash

start_time="$(date -u +%s)"
end_time="$(date -u +%s)"

if [ $# -ne 1 ]; then
  echo "Need to window path"
  kill -15 $$
elif [ $1 -eq "1" ]; then
  sudo rm -rf $1/window.log
  touch $1/window.log
fi

# window check
  while [ 1 -eq 1 ]; do
    window1=$(sudo nvme admin-passthru /dev/nvme1 -n 0x1 -o 0x0a -r --cdw10=0x14 --cdw11=0x01 2>&1 > /dev/null | tail -c 2)
    window2=$(sudo nvme admin-passthru /dev/nvme1 -n 0x1 -o 0x0a -r --cdw10=0x14 --cdw11=0x02 2>&1 > /dev/null | tail -c 2)
    window3=$(sudo nvme admin-passthru /dev/nvme1 -n 0x1 -o 0x0a -r --cdw10=0x14 --cdw11=0x03 2>&1 > /dev/null | tail -c 2)
    window4=$(sudo nvme admin-passthru /dev/nvme1 -n 0x1 -o 0x0a -r --cdw10=0x14 --cdw11=0x04 2>&1 > /dev/null | tail -c 2)

    if [ $window1 == "1" -a $window2 == "1" -a $window3 == "1" -a $window4 == "1" ]; then
      # "%H:%M:%S.%N"
      end_time="$(date -u +%s)"
      echo $(($end_time-$start_time)) 1 >> $1/window.log
    else
      end_time="$(date -u +%s)"
      echo $(($end_time-$start_time)) 0 >> $1/window.log
    fi

    sleep 1

  done
