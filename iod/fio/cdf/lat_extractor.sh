#!/bin/bash

############################################################
#   parsing 99 ~ longest latency from cdf format latenct log
#
#   "./parsing_latency_in_cdf.sh"
#
#   CDF_OUTPUT : csv path
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

CDF_OUTPUT=$1

LAT95=$(sed -rn 's/^([0-9].+),0.95.+$/\1/p' ${CDF_OUTPUT} | head -n 1)
LAT99=$(sed -rn 's/^([0-9].+),0.99.+$/\1/p' ${CDF_OUTPUT} | head -n 1)
LAT999=$(sed -rn 's/^([0-9].+),0.999.+$/\1/p' ${CDF_OUTPUT} | head -n 1)
LAT9999=$(sed -rn 's/^([0-9].+),0.9999.+$/\1/p' ${CDF_OUTPUT} | head -n 1)
LAT99999=$(sed -rn 's/^([0-9].+),0.99999.+$/\1/p' ${CDF_OUTPUT} | head -n 1)
LONGEST=$(sed -rn 's/^([0-9].+),0.99999.+$/\1/p' ${CDF_OUTPUT} | tail -n 1)

echo 1 $LAT95 95th > ${CDF_OUTPUT}_lat
echo 2 $LAT99 99th >> ${CDF_OUTPUT}_lat
echo 3 $LAT999 99.9th >> ${CDF_OUTPUT}_lat
echo 4 $LAT9999 99.99th >> ${CDF_OUTPUT}_lat
echo 5 $LAT99999 99.999th >> ${CDF_OUTPUT}_lat
echo 6 $LONGEST longest >> ${CDF_OUTPUT}_lat
