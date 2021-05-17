set terminal jpeg
set datafile separator ','

set title "cdf"
set xlabel "Latency"
set ylabel "cdf"

set output "/home/data/iod/blktrace/cdf/cdf_016_004K_050.jpg"

plot \
"/home/data/iod/blktrace/csv/randrw_016_004K_050_ndwin.txt.formatted.csv" using 1:2 title "NDWIN", \
"/home/data/iod/blktrace/csv/randrw_016_004K_050_dtwin.txt.formatted.csv" using 1:2 title "DTWIN"
  