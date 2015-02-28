set -e -x -u

num_cells=$1

cd ~/workspace/diego-release
./scripts/generate-deployment-manifest aws ../cf-release ~/workspace/deployments-runtime/diego-1/stubs/* ~/workspace/deployments-runtime/diego-1/performance-stubs/${num_cells}-cell.yml ~/workspace/deployments-runtime/diego-1/performance-stubs/debug_logging.yml > ~/workspace/deployments-runtime/diego-1/deployments/diego-${num_cells}-cell.yml
