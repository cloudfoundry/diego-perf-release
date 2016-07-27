fetch_logs() {
  download_dir=$1
  job=$2
  index=$3
  log_filter_pattern=$4

  vm_log_dir="${download_dir}/${job}-${index}"
  mkdir -p ${vm_log_dir}
  if [ "$(ls -A ${vm_log_dir})" ]; then
    echo "Already populated ${vm_log_dir}, skipping..."
  else
    bosh logs $job $index --only "${log_filter_pattern}" --dir ${vm_log_dir}
    cd ${vm_log_dir}
    tar -xzvf *
    gunzip -r .
  fi
}

source $(dirname $0)/bosh_wrapper.sh

if [ -z "$2" ]; then
  echo "Usage: $0 <num_cells> <download_dir>"
  echo "       <num_cells> must be one of '10', '20', '50', or '100'"
  exit 1
fi

set -e -u

num_cells=$1
download_dir=$2

mkdir -p ${download_dir}

for index in $(seq 0 0); do
  for job in database_z1 database_z2 database_z3; do
    (
      fetch_logs $download_dir $job $index 'bbs/bbs.stdout*'
    ) &
  done
  wait
done

for index in $(seq 0 0); do
  for job in brain_z1 brain_z2; do
    (
      fetch_logs $download_dir $job $index 'auctioneer/auctioneer*,converger/converger*'
    ) &
  done
  wait
done

# Get rep and garden-linux logs, 5 VMs at a time
# Assuming there are num_cells cell VMs split evenly across 2 zones
for job in cell_z1 cell_z2; do
  for i in $(seq 0 $((${num_cells} / 10 - 1))); do
    for index in $(seq $(($i * 5)) $(($i * 5 + 4))); do
      (
        fetch_logs $download_dir $job $index 'garden/garden*,rep/rep.stdout*'
      ) &
    done
    wait
  done
done
