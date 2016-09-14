#!/bin/bash

run_batch() {
   i=$1

   cf create-space cedar-$i
   cf t -s cedar-$i
   /var/vcap/packages/cedar/bin/cedar -n 20 -k 40 -payload /var/vcap/packages/cedar/assets/temp-app -config /var/vcap/packages/cedar/config.json -timeout 2m -max-polling-errors 5 -prefix cedar${i} -output /var/vcap/sys/log/cedar/cedar-$i-output.json > /var/vcap/sys/log/cedar/cedar.stdout-${i}.log 2> /var/vcap/sys/log/cedar/cedar.stderr-${i}.log
}

for i in `seq 10`; do
  read -p "You're about to run the batch #$i. Ok? [y|n]" -n 1 -r < /dev/tty
  echo
  if ! echo $REPLY | grep -E '^[Yy]$' > /dev/null; then
    echo "cancelled yo"
    exit 1
  fi

  echo "Running Batch #$i at `date +%s`"
  pushd /var/vcap/packages/cedar > /dev/null
    run_batch $i
  popd > /dev/null
  echo "Finished Running Batch #$i at `date +%s`"
done
