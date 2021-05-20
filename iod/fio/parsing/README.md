blkparse /homa/data/iod/DB-data/nvme2n1 -o output

./blkprase_parser /home/data/iod/DB-data/output /home/data/iod/DB-data/output-dc

#### R W수정 필요
python trace_formatter.py trace_formatter_config_db.yaml