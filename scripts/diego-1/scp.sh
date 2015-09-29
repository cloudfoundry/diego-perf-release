source $(dirname $0)/bosh_wrapper.sh

if [ -z "$4" ]; then
  echo "Usage: $0 <deployment> <num_cells> <job> <index> <source> <destination>"
  echo "       <deployment> must be one of 'perf', 'diego', or 'cf'"
  echo "       <num_cells> must be one of '10', '20', '50', or '100'"
  exit 1
fi

set -e -u -x

deployment=$1
num_cells=$2
job=$3
index=$4
source=$5
destination=$6

fast_bosh \
  -t micro.diego-1.cf-app.com \
  -d ~/workspace/deployments-runtime/diego-1/deployments/${num_cells}-cell-experiment/${deployment}.yml \
  scp $job $index --download $source $destination \
  --gateway_user vcap \
  --gateway_host micro.diego-1.cf-app.com \
  --public_key ~/workspace/deployments-runtime/diego-1/keypair/id_rsa_bosh.pub
