#!/bin/bash

sudo ./GC_test_read_plm_off.sh
sudo ./GC_test_read_ndwin.sh
sudo ./GC_test_read_dtwin.sh
sudo ./GC_test_read_dtwin_plm_off.sh
sudo ./GC_test_read_dtwin_ndwin_write.sh

sudo mv /home/iod/NVMset4/GC/read-plm-off /home/iod/NVMset4/GC/read-plm-off-1
sudo mv /home/iod/NVMset4/GC/read-ndwin /home/iod/NVMset4/GC/read-ndwin-1
sudo mv /home/iod/NVMset4/GC/read-dtwin /home/iod/NVMset4/GC/read-dtwin-1
sudo mv /home/iod/NVMset1/GC/read-dtwin-plm-off /home/iod/NVMset1/GC/read-dtwin-plm-off-1
sudo mv /home/iod/NVMset1/GC/read-dtwin-ndwin-write /home/iod/NVMset1/GC/read-dtwin-ndwin-write-1

sudo ./GC_test_read_plm_off.sh
sudo ./GC_test_read_ndwin.sh
sudo ./GC_test_read_dtwin.sh
sudo ./GC_test_read_dtwin_plm_off.sh
sudo ./GC_test_read_dtwin_ndwin_write.sh

sudo mv /home/iod/NVMset4/GC/read-plm-off /home/iod/NVMset4/GC/read-plm-off-2
sudo mv /home/iod/NVMset4/GC/read-ndwin /home/iod/NVMset4/GC/read-ndwin-2
sudo mv /home/iod/NVMset4/GC/read-dtwin /home/iod/NVMset4/GC/read-dtwin-2
sudo mv /home/iod/NVMset1/GC/read-dtwin-plm-off /home/iod/NVMset1/GC/read-dtwin-plm-off-2
sudo mv /home/iod/NVMset1/GC/read-dtwin-ndwin-write /home/iod/NVMset1/GC/read-dtwin-ndwin-write-2

sudo ./GC_test_read_plm_off.sh
sudo ./GC_test_read_ndwin.sh
sudo ./GC_test_read_dtwin.sh
sudo ./GC_test_read_dtwin_plm_off.sh
sudo ./GC_test_read_dtwin_ndwin_write.sh

sudo mv /home/iod/NVMset4/GC/read-plm-off /home/iod/NVMset4/GC/read-plm-off-3
sudo mv /home/iod/NVMset4/GC/read-ndwin /home/iod/NVMset4/GC/read-ndwin-3
sudo mv /home/iod/NVMset4/GC/read-dtwin /home/iod/NVMset4/GC/read-dtwin-3
sudo mv /home/iod/NVMset1/GC/read-dtwin-plm-off /home/iod/NVMset1/GC/read-dtwin-plm-off-3
sudo mv /home/iod/NVMset1/GC/read-dtwin-ndwin-write /home/iod/NVMset1/GC/read-dtwin-ndwin-write-3
