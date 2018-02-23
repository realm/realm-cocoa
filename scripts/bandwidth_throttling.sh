#!/bin/bash

set -o pipefail
set -e

######################################
# Simulating Poor Network Connectivity
######################################
enable_bandwidth_throttling() {
    # run inside sudo
    sudo sh <<SCRIPT
        dnctl pipe 1 config bw $1 plr $2 delay $3
        dnctl list
        echo "dummynet out proto tcp from 127.0.0.1 to 127.0.0.1 pipe 1" | pfctl -f -
        pfctl -e
SCRIPT
}

disable_bandwidth_throttling() {
    # run inside sudo
    sudo sh <<SCRIPT
        dnctl -f flush
        pfctl -f /etc/pf.conf
        pfctl -d
SCRIPT
}
