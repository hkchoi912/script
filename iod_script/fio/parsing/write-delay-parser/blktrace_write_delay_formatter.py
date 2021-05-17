'''
    if D: intsert [timestamp, interval, address] in output list   
'''

import yaml
import os
import sys
import glob
import numpy as np
import pandas as pd
import re
import csv
import shutil
from multiprocessing import Pool

with open(sys.argv[1], 'r') as f:
    opt = yaml.load(f, Loader=yaml.FullLoader)


def format_file(filepath):
    df = pd.read_table(filepath, sep=opt['delimiter'],
                       names=opt['names'], dtype=opt['typedict'])

    df.drop(['dev<mjr,mnr>', 'cpu', 'seq_num', 'pid',
             '+'], axis='columns', inplace=True)
    df.dropna(how='any', inplace=True)
    df.reset_index(drop=True, inplace=True)

    output = []
    print("     collect data...")

    for i in range(1, len(df)):
        # and df['exec'][i] == opt['program']
        if df['event'][i] == 'D' and opt['iotype'] in df['rwsb'][i]:
            # list element: [[timestamp, interval, address], ... ]
            output.append(
                [df['timestamp'][i], 0, df['address'][i], df['bs'][i]])

        elif df['event'][i] == 'C' and opt['iotype'] in df['rwsb'][i] and df['exec'][i] == '[0]':
            for j in reversed(range(0, len(output))):
                # same address, interval not yet recorded
                if output[j][2] == df['address'][i] and output[j][1] == 0:
                    interval = np.float64(
                        1000000)*(np.float64(df['timestamp'][i]) - np.float64(output[j][0]))
                    output[j][1] = interval
                    break

    print("     write data...")

    output_file = os.path.join(opt['parsing_result_dir'], os.path.basename(filepath)+opt['parsing_result_format'])  # output.parsing
    with open(output_file, 'w') as f:
        for i in range(0, len(output)):
            f.write("%s %s %s\n" % (output[i][0], output[i][1], output[i][3]))
            # if str(type(output[key])) == "<class 'list'>":

    # move blkparse raw data to raw directory
    # if not os.path.exists(opt['blkparse_raw_dir']):
        # os.makedirs(opt['blkparse_raw_dir'], exist_ok=True)
    # shutil.move(filepath, os.path.join(
        # opt['blkparse_raw_dir'], os.path.basename(filepath)))


def main():
    file_pattern = os.path.join(
        opt['blkparse_result_dir'], opt['blkparse_result_format'])
    file_list = glob.glob(file_pattern)

    if not os.path.exists(opt['parsing_result_dir']):
        os.makedirs(opt['parsing_result_dir'], exist_ok=True)

    with Pool(processes=8) as pool:
        pool.map(format_file, file_list)


if __name__ == '__main__':
    main()


##=======================================================
bad_words = ['bad', 'naughty']

with open('oldfile.txt') as oldfile, open('newfile.txt', 'w') as newfile:
    for line in oldfile:
        if not any(bad_word in line for bad_word in bad_words):
            newfile.write(line)