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

    df.drop(['dev<mjr,mnr>', 'cpu', 'seq_num', 'pid','+'], axis='columns', inplace=True)
    df.dropna(how='any', inplace=True)
    df.reset_index(drop=True, inplace=True)

    output = []
    print("     collect data...")

    output_file = os.path.join(opt['parsing_result_dir'], os.path.basename(filepath)+opt['parsing_result_format'])

    with open(output_file, 'w') as f:
        for i in range(0, len(df)):
            if df['event'][i] == 'D' and ('R' in df['rwsb'][i] or 'W' in df['rwsb'][i]) :
                f.write("%s\n" % df[i]) 

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
