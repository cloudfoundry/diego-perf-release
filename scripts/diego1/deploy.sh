source $(dirname $0)/bosh_wrapper.sh

if [ -z "$2" ]; then
  echo "Usage: $0 <deployment> <num_cells>"
  echo "       <deployment> must be one of 'diego' or 'perf'"
  echo "       <num_cells> must be one of '10', '20', '50', or '100'"
  exit 1
fi

set -e -x -u

deployment=$1
num_cells=$2

fast_bosh target diego1

if [ "$deployment" == "diego" ]; then
  fast_bosh deployment ~/workspace/deployments-runtime/diego-1/deployments/diego-${num_cells}-cell.yml
  cd ~/workspace/diego-release
elif [ "$deployment" == "perf" ]; then
  fast_bosh deployment ~/workspace/deployments-runtime/diego-1/deployments/diego-perf-${num_cells}-cell.yml
  cd ~/workspace/perf-release-diego
else
  echo "Unrecognized deployment '${deployment}'"
  exit 1
fi

fast_bosh create release --force
fast_bosh -n upload release --rebase
fast_bosh -n deploy
