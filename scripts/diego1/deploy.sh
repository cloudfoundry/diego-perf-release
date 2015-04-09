source $(dirname $0)/bosh_wrapper.sh

if [ -z "$2" ]; then
  echo "Usage: $0 <deployment> <num_cells>"
  echo "       <deployment> must be one of 'cf', 'diego', or 'perf'"
  echo "       <num_cells> must be one of '10', '20', '50', or '100'"
  exit 1
fi

set -e -x -u

deployment=$1
num_cells=$2

if [ "$deployment" == "cf" ]; then
  cd ~/workspace/cf-release
elif [ "$deployment" == "diego" ]; then
  cd ~/workspace/diego-release
elif [ "$deployment" == "perf" ]; then
  cd ~/workspace/perf-diego-release
else
  echo "Unrecognized deployment '${deployment}'"
  exit 1
fi

fast_bosh target diego1
fast_bosh deployment ~/workspace/deployments-runtime/diego-1/deployments/${num_cells}-cell-experiment/${deployment}.yml
fast_bosh create release --force
fast_bosh -n upload release --rebase
fast_bosh -n deploy
