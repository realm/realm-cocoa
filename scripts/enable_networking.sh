set -o pipefail
set -e

source ./scripts/bandwidth_throttling.sh

disable_bandwidth_throttling
