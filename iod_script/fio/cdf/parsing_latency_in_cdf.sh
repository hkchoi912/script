#!/bin/bash

############################################################
#   parsing 99 ~ longest latency from cdf format latenct log 
#
#   "./parsing_latency_in_cdf.sh"
#   
#   CSV_PATH : csv path
#   FILE_NAME : output file name
#   
#   input format example
#   lat  cdf
#   4763,0.9999963222345584
#   4764,0.9999963222345584
#   4765,0.9999963222345584
#   4766,0.9999963222345584
#   4767,0.9999963222345584
#
############################################################

CSV_PATH='/home/data/iod/DB-data/parsing/zippydb-180min-iod'
FILE_NAME='lat.csv'

if [ -f $CSV_PATH/$FILE_NAME ]; then
    rm -rf $CSV_PATH/$FILE_NAME
fi


for file in $CSV_PATH/*.csv; do
    LAT99=$(sed -rn 's/^([0-9].+),0.99.+$/\1/p' $file | head -n 1)
    LAT999=$(sed -rn 's/^([0-9].+),0.999.+$/\1/p' $file | head -n 1)
    LAT9999=$(sed -rn 's/^([0-9].+),0.9999.+$/\1/p' $file | head -n 1)
    LAT99999=$(sed -rn 's/^([0-9].+),0.99999.+$/\1/p' $file | head -n 1)
    LONGEST=$(sed -rn 's/^([0-9].+),0.99999.+$/\1/p' $file | tail -n 1)

    echo $(basename $file) $LAT99 $LAT999 $LAT9999 $LAT99999 $LONGEST >> $CSV_PATH/$FILE_NAME
    #echo $LAT99 $LAT999 $LAT9999 $LAT99999 $LONGEST
    #echo $LAT99
    #echo $LAT999
    #echo $LAT9999
    #echo $LAT99999
    #echo $LONGEST
done
