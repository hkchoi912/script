#!/bin/bash

FILE_PATH='/home/data/iod/replay/permanent/qd-bs-test/no-format-fill/*/*'
rm tail.csv

for CSV in $FILE_PATH/*_parsingcdf.csv; do
    echo $(tail -n 1 $CSV | sed -rn 's/([0-9]+),.+/\1/p') >> tail.csv
done

for CSV in $FILE_PATH/*_parsingcdf.csv; do
    echo $(basename $CSV) $(tail -n 1 $CSV | sed -rn 's/([0-9]+),.+/\1/p') >> tail.csv
done

