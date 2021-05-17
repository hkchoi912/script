import numpy
import os
import glob
from multiprocessing import Pool

trace_result_dir= '/home/data/iod/interval/fio_lat_log'
trace_result_format = 'fio_lat_result.log'
fio_lat_dir= '/home/data/iod/interval/fio_lat_log'
output_avg_csv = '/home/data/iod/interval/fio_lat_log/timeline_lat.csv'

def calculate_avg(file_path):
    #calculate avg latency
    if os.path.isfile(file_path):
        total_1 = 0
        total_2 = 0
        total_3 = 0
        total_4 = 0
        len = 0

        with open(file_path) as f:
            for line in f:
                if float(line.split()[0]) < 30000:
                    total_1 += float(line.split()[1])/1000
                    len += 1
                elif float(line.split()[0]) < 60000:
                    total_2 += float(line.split()[1])/1000
                    len += 1
                elif float(line.split()[0]) < 90000:
                    total_3 += float(line.split()[1])/1000
                    len += 1
                else:
                    total_4 += float(line.split()[1])/1000
                    len += 1
                        
            total_1 = total_1/len
            total_2 = total_2/len
            total_3 = total_3/len
            total_4 = total_4/len
        
    if not os.path.exists(fio_lat_dir):
        os.makedirs(fio_lat_dir, exist_ok=True) #make csv path
    
    with open(output_avg_csv, "a") as f: #append data
        f.write("%s %s %s %s %s\n" % (os.path.basename(file_path), total_1, total_2, total_3, total_4))
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