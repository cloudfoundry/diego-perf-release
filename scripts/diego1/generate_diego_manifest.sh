if [ -z "$1" ]; then
  echo "Usage: $0 <num_cells>"
  echo "        <num_cells> must be one of '10', '20', '50', or '100'"
  exit 1
fi

set -e -x -u

num_cells=$1

cd ~/workspace/diego-release
./scripts/generate-deployment-manifest                                             \
  aws                                                                              \
  ../cf-release                                                                    \
  ~/workspace/deployments-runtime/diego-1/stubs/*                                  \
  ~/workspace/deployments-runtime/diego-1/performance-stubs/${num_cells}-cell.yml  \
  ~/workspace/deployments-runtime/diego-1/performance-stubs/debug_logging.yml      \
  ~/workspace/deployments-runtime/diego-1/performance-stubs/disable_disk_quota.yml \
  > ~/workspace/deployments-runtime/diego-1/deployments/diego-${num_cells}-cell.yml
