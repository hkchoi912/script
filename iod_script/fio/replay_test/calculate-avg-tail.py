
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
from multiprocessing import Pool
#default: '/home/data/iod/blktrace/formatted'
trace_result_dir = '/home/data/iod/replay/permanent/qd-bs-test/*/*/parsing'
trace_result_format = '*_onlyread_parsing'
csv_dir = '/home/data/iod/permanent_data/blktrace/csv/'
output_avg_csv = '/home/data/iod/blktrace/csv/avg.csv'

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

def calculate_avg(parsing_file):
    parsing_path = os.path.dirname(parsing_file)
    output_avg_csv = os.path.join(parsing_path, 'avg.csv')
    output_cdf_csv = os.path.join(parsing_path, os.path.basename(parsing_file)+'cdf.csv')
    distance = []
    
    # calculate avg latency
    if os.path.isfile(parsing_file):
        total = 0
        len = 0
        with open(parsing_file) as f:
            for line in f:
                if float(line.split()[1]) < 10000000:
                    total += float(line.split()[1])
                    distance.append(float(line.split()[1])/1000)
                    len += 1

            avg = total / (len*1000)

    xvalues, yvalues = cal_cdf(distance)
    df = pd.DataFrame({"distance": xvalues, "cdf": yvalues})

    df.to_csv(output_cdf_csv, index=False)

    with open(output_avg_csv, "a") as f:  # append data
        #f.write("%s %s\n" % (os.path.basename(parsing_file), avg))
        f.write("%s\n" % (avg))
        f.close

def main():
    file_pattern = os.path.join(trace_result_dir, trace_result_format)
    file_list = glob.glob(file_pattern)
    file_list.sort()

    for i in file_list:
        target1 = os.path.join(os.path.dirname(i), 'avg.csv')
        if os.path.isfile(target1):
            os.remove(target1)

        target2 = os.path.join(os.path.dirname(i), 'cdf.csv')
        if os.path.isfile(target2):
            os.remove(target2)


    with Pool(processes=1) as pool:
        pool.map(calculate_avg, file_list)

if __name__ == "__main__":
    main()