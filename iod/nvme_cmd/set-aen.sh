#!/bin/bash

# asynchronous event configuration
sudo nvme set-feature /dev/nvme1n2 -n 1 -f 11 -v 1

# predictable latency mode config
sudo nvme set-feature /dev/nvme1n2 -n 1 -f 19 -v 1

# predictable latency mode window
sudo nvme set-feature /dev/nvme1n2 -n 1 -f 20 -v 1
