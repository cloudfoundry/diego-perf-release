source $(dirname $0)/bosh_wrapper.sh

if [[ -z "$2" ]] || [[ ! -z "$3" && "$3" != "--rebase" ]]; then
  echo "Usage: $0 <deployment> <num_cells> [--rebase]"
  echo "       <deployment> must be one of 'cf', 'diego', or 'perf'"
  echo "       <num_cells> must be one of '10', '20', '50', or '100'"
  exit 1
fi

deployment=$1
num_cells=$2
rebase=""
if [[ ! -z "$3" ]]; then
  rebase=$3
fi

set -e -x -u

if [ "$deployment" == "cf" ]; then
  cd ~/workspace/cf-release
elif [ "$deployment" == "diego" ]; then
  cd ~/workspace/diego-release
elif [ "$deployment" == "perf" ]; then
  cd ~/workspace/diego-perf-release
else
  echo "Unrecognized deployment '${deployment}'"
  exit 1
fi

fast_bosh create release --force
fast_bosh -t micro.diego-1.cf-app.com -n upload release ${rebase}
fast_bosh -t micro.diego-1.cf-app.com -d ~/workspace/deployments-runtime/diego-1/deployments/${num_cells}-cell-experiment/${deployment}.yml -n deploy
# while ! bosh -t micro.diego-1.cf-app.com -d ~/workspace/deployments-runtime/diego-1/deployments/${num_cells}-cell-experiment/${deployment}.yml -n deploy; do
#   echo "*** RETRYING DEPLOY ***"
# done
