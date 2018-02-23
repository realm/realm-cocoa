set -o pipefail
set -e

source ./scripts/bandwidth_throttling.sh

# Set 100% packet loss
enable_bandwidth_throttling '40Mbit/s' 100 0
