### blktrace & blkparse fio

in `fio/blktrace_test/`

```shell
./blktrace_test.sh [window select]  #0=ndwin, 1=dtwin, 2=both
```

### parsing from blkparsing file.

in `fio/parsing/`

```shell
python trace_formatter_WAR.py trace_formatter_config.yaml
```

configure input in \_config.yaml

### Make latency distribution csv file

in `fio/cdf/`

```shell
python cdf.py
```

### Make cdf.jpg using csv.file

in `fio/cdf/`

```shell
gnuplot cdf.gnuplot
```

### Calculate avg latency and save avg.csv file

in `fio/cdf/`

```shell
python avg.py
```
