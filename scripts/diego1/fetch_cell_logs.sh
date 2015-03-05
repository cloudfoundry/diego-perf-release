source $(dirname $0)/bosh_wrapper.sh

if [ -z "$4" ]; then
  echo "Usage: $0 <num_cells> <download_dir> <start_timestamp> <end_timestamp>"
  echo "       <num_cells> must be one of '10', '20', '50', or '100'"
  echo "       the timestamps are seconds since epoch, e.g 1425061818.123456993"
  exit 1
fi

set -x -e -u

num_cells=$1
download_dir=$2
start_timestamp=$3
end_timestamp=$4

fast_bosh target diego1
fast_bosh deployment ~/workspace/deployments-runtime/diego-1/deployments/diego-${num_cells}-cell.yml

mkdir ${download_dir}

for job in cell_z1 cell_z2; do
  for i in $(seq 0 $((${num_cells} / 10 - 1))); do
    for index in $(seq $(($i * 5)) $(($i * 5 + 4))); do
      (
        mkdir -p ${download_dir}/${job}-${index}
        fast_bosh logs $job $index --only 'garden-linux/garden-linux.stdout*,executor/executor.stdout*,rep/rep.stdout*,receptor/receptor.stdout*' --dir ${download_dir}/${job}-${index}
        cd ${download_dir}/${job}-${index}
        tar -xzvf *
        gunzip -r .
      ) &
    done
    wait
  done
done

veritas chug-unify --min=${start_timestamp} --max=${end_timestamp} ${download_dir}/*/executor/executor.stdout* ${download_dir}/*/rep/rep.stdout* ${download_dir}/*/receptor/receptor.stdout* > ${download_dir}/unity.log

cd /Users/pivotal/go/src/github.com/onsi/cicerone
go run main.go fezzik-tasks ${download_dir}/unity.log
