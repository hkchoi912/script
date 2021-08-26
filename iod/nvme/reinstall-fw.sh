TARGET=/dev/nvme1n2
TARGET_NON=/dev/nvme3
IOD_FW=/home/hkchoi/src/firmware/IOD/ETA5N401_20190802_ENC.bin
NON_IOD_FW=/home/hkchoi/src/firmware/NonIOD/EDA5002Q_NF.bin

# step1: fw download to NVMe drive
nvme fw-download ${TARGET} -f ${NON_IOD_FW}

# step2: activate fw to target device
nvme fw-activate ${TARGET} -s 0 -a 1

# step3: reset for loading fw
nvme reset ${TARGET}

# step4: try to format
nvme format ${TARGET} -l 0 -n 1