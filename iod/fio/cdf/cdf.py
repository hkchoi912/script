#!/usr/bin/python

############################################################
# make io latency log to cdf format
#
# "python cdf.py"
#   
# trace_result_dir & format : set input file  
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
trace_result_dir= '/home/data/iod/DB-data/parsing/zippydb-180min-iod'
trace_result_format = '*.write'
csv_dir= '/home/data/iod/DB-data/parsing/zippydb-180min-iod'
csv_format= '.csv'
cdf_dir= '/home/data/iod/DB-data/parsing/zippydb-180min-iod' #cdf.jpg will be saved

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
    #xvalues = numpy.arange(0, float(math.ceil(max(data))), 0.1) #max=return max value
    yvalues = [cdf(point) for point in xvalues]
    return xvalues, yvalues


def blktrace_latency(file_path):
    distance = []

    if os.path.isfile(file_path):
        with open(file_path) as f:
            num_line = 0
            for line in f:
                distance.append(float(line.split()[1]))
                num_line += 1

    xvalues, yvalues = cal_cdf(distance)
    df = pd.DataFrame({"distance": xvalues, "cdf": yvalues})

    if not os.path.exists(csv_dir):
        os.makedirs(csv_dir, exist_ok=True) #make csv path
    
    output_file = os.path.join(csv_dir, os.path.basename(file_path)+csv_format)

    df.to_csv(output_file, index=False)


def main():
    file_pattern = os.path.join(trace_result_dir, trace_result_format)
    file_list = glob.glob(file_pattern)

    with Pool(processes=4) as pool:
        pool.map(blktrace_latency, file_list)

if __name__ == "__main__":
    main()
