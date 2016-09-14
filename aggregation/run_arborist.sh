#!/bin/bash

run_batch() {
   cf create-space cedar-extra
   cf t -s cedar-extra

   /var/vcap/packages/cedar/bin/cedar -n 1 -k 40 -payload /var/vcap/packages/cedar/assets/temp-app -config /var/vcap/packages/cedar/config_extra.json -timeout 2m -max-polling-errors 5 -prefix cedar-extra -output /var/vcap/sys/log/cedar/cedar-extra-output.json > /var/vcap/sys/log/cedar/cedar.stdout-extra.log 2> /var/vcap/sys/log/cedar/cedar.stderr-extra.log

   /var/vcap/packages/arborist/bin/arborist -app-file /var/vcap/sys/log/cedar/cedar-extra-output.json -result-file /var/vcap/sys/log/arborist/arborist-output.json -domain diego-2.cf-app.com -duration 10m > /var/vcap/sys/log/arborist/arborist.stdout.log 3> /var/vcap/sys/log/arborist/arborist.stderr.log
}

echo "Running Batch #$i at `date +%s`"
pushd /var/vcap/packages/cedar > /dev/null
  run_batch $i
popd > /dev/null
echo "Finished Running Batch #$i at `date +%s`"
