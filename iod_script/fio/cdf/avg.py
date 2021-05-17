import numpy
import os
import glob
from multiprocessing import Pool
#default: '/home/data/iod/blktrace/formatted'
trace_result_dir= '/home/data/iod/blktrace/formatted'
trace_result_format = '*.formatted'
csv_dir= '/home/data/iod/permanent_data/blktrace/csv/'
output_avg_csv = '/home/data/iod/blktrace/csv/avg.csv'

def calculate_avg(file_path):
    #calculate avg latency
    if os.path.isfile(file_path):
        total = 0
        len = 0
        with open(file_path) as f:
            for line in f:
                total += float(line.split()[1])
                len += 1        
            avg = total / len
        
    if not os.path.exists(csv_dir):
        os.makedirs(csv_dir, exist_ok=True) #make csv path
    
    with open(output_avg_csv, "a") as f: #append data
        f.write("%s %s\n" % (os.path.basename(file_path), avg))
        f.close


def main():
    file_pattern = os.path.join(trace_result_dir, trace_result_format)
    file_list = glob.glob(file_pattern)

    if os.path.isfile(output_avg_csv):
        os.remove(output_avg_csv) #if avg.csv already exist, remove
    
    with Pool(processes=1) as pool:
        pool.map(calculate_avg, sorted(file_list))

if __name__ == "__main__":
    main()