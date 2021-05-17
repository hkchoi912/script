#!/bin/bash

LOG_FILE='/home/data/iod/interval/fio_lat_log'
FILE_NAME='randread_clat.1.log'
NEW_FILE_NAME='fio_lat_result.log'

sed -rn 's/^([0-9]+), ([0-9]+), ., ., .$/\1 \2/p' $LOG_FILE/$FILE_NAME > $LOG_FILE/$NEW_FILE_NAME