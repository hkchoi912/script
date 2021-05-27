#!/usr/bin/python

############################################################
# make io latency log to cdf format
#
# "python cdf.py"
#   
# D2C_extractor_output & format : set input file  
# csv_dir & formatted : set output csv file
#   
# input format example
#    time           latency    don'care
#    0.000013355    98.004     512
#    0.000017372    172.905    512
#    0.000020408    253.065    512
#    0.000022803    332.203    512
#
############################################################

import re
import os
import sys
import numpy as np
import numpy
import pandas as pd
import math
import glob
from bisect import bisect_left
from multiprocessing import Pool

D2C_extractor_output= sys.argv[1]
csv_format= '_cdf'

class discrete_cdf:
    def __init__(self, data):
        self._data = data  # must be sorted
        self._data_len = float(len(data))

    def __call__(self, point):
        return (len(self._data[:bisect_left(self._data, point)]) /
                self._data_len)

def cal_cdf(data):
    cdf = discrete_cdf(np.sort(data))
    xvalues = range(0, int(math.ceil(max(data))))
    yvalues = [cdf(point) for point in xvalues]
    return xvalues, yvalues

def blktrace_latency(file):
    distance = []

    if os.path.isfile(file):
        with open(file) as f:
            num_line = 0
            for line in f:
                distance.append(float(line.split()[1]))
                num_line += 1

    xvalues, yvalues = cal_cdf(distance)
    df = pd.DataFrame({"distance": xvalues, "cdf": yvalues})
   
    output_file = file + csv_format

    df.to_csv(output_file, index=False)


def main():   
    file = [D2C_extractor_output]

    with Pool(processes=4) as pool:
        pool.map(blktrace_latency, file)

if __name__ == "__main__":
    main()
