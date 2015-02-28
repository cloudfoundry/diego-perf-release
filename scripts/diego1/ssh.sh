source $(dirname $0)/bosh_wrapper.sh

if [ -z "$4" ]; then
  echo "Usage: $0 <deployment> <num_cells> <job> <index>"
  echo "       <deployment> must be one of 'perf', 'diego', or 'cf'"
  echo "       <num_cells> must be one of '10', '20', '50', or '100'"
  exit 1
fi

set -e -u -x

deployment=$1
num_cells=$2
job=$3
index=$4

fast_bosh target diego1

if [ "$deployment" == "perf" ]; then
  manifest=~/workspace/deployments-runtime/diego-1/deployments/diego-perf-${num_cells}-cell.yml
elif [ "$deployment" == "diego" ]; then
  manifest=~/workspace/deployments-runtime/diego-1/deployments/diego-${num_cells}-cell.yml
elif [ "$deployment" == "cf" ]; then
  manifest=~/workspace/deployments-runtime/diego-1/deployments/cf-$(($num_cells / 5))-cc.yml
else
  echo "Unrecognized deployment ${deployment}"
  exit 1
fi

fast_bosh -d $manifest ssh $job $index --gateway_user vcap --gateway_host micro.diego-1.cf-app.com --public_key ~/workspace/deployments-runtime/diego-1/keypair/id_rsa_bosh.pub
