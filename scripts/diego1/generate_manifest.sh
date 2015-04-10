if [ -z "$2" ]; then
  echo "Usage: $0 <deployment> <num_cells>"
  echo "        <deployment> must be one of 'cf', 'diego'"
  echo "        <num_cells> must be one of '10', '20', '50', or '100'"
  exit 1
fi

set -e -x -u

deployment=$1
num_cells=$2

case "${deployment}" in
  cf)
    pushd ~/workspace/cf-release
    ./generate_deployment_manifest \
      aws \
      ~/workspace/deployments-runtime/diego-1/stubs/director-uuid.yml \
      ~/workspace/deployments-runtime/diego-1/stubs/cf/*.yml \
      ~/workspace/deployments-runtime/diego-1/stubs/cf/${num_cells}-cell-experiment/instance-counts.yml \
      > ~/workspace/deployments-runtime/diego-1/deployments/${num_cells}-cell-experiment/cf.yml
    popd
    ;;
  diego)
    tmpdir=$(mktemp -d /tmp/deploy-diego.XXXXX)
    pushd ~/workspace/diego-release
    spiff merge \
      ~/workspace/diego-release/manifest-generation/misc-templates/iaas-settings.yml \
      ~/workspace/deployments-runtime/diego-1/templates/diego/iaas-settings-internal.yml \
      ~/workspace/deployments-runtime/diego-1/stubs/aws-resources.yml \
      > ${tmpdir}/iaas-settings.yml
    ./scripts/generate-deployment-manifest \
      ~/workspace/deployments-runtime/diego-1/stubs/director-uuid.yml \
      ~/workspace/deployments-runtime/diego-1/stubs/diego/property-overrides.yml \
      ~/workspace/deployments-runtime/diego-1/stubs/diego/${num_cells}-cell-experiment/instance-count-overrides.yml \
      ~/workspace/deployments-runtime/diego-1/stubs/diego/persistent-disk-overrides.yml \
      ${tmpdir}/iaas-settings.yml \
      ~/workspace/deployments-runtime/diego-1/stubs/diego/additional-jobs.yml \
      ~/workspace/deployments-runtime/diego-1/deployments/${num_cells}-cell-experiment \
      > ~/workspace/deployments-runtime/diego-1/deployments/${num_cells}-cell-experiment/diego.yml
    popd
    ;;
  *)
    echo "Invalid deployment '${deployment}'"
    exit 1
    ;;
esac
