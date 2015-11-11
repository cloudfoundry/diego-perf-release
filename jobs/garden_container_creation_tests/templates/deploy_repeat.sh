#!/bin/bash

set -xe

if [ $# != 4 ]; then
  echo "Usage: $(basename $0) SUFFIX NUM SCALING_ITERATIONS RESULTS_FILE"
  echo
  echo "Will deploy four apps, scale them to 15 instances total, and repeat NUM times"
  exit 2
fi

suffix=$1
numtimes=$2
scaling_iterations=$3
results_file=$4

check_state() {
  name=$1
  instances=$2

  for i in `seq 600`; do
    if [[ $(cf app $name | grep "#" | egrep -v "(starting|stopped)" | wc -l) -eq $instances ]]; then
      return
    fi
    sleep 0.1
  done
  exit 1
}

touch $results_file

APPS_DIR=/var/vcap/packages/stress_tests/src/github.com/cloudfoundry-incubator/diego-stress-tests/assets/apps

for i in `seq $numtimes`; do
  echo "[$suffix] Pushing apps..."

  cf push westley-$suffix -p $APPS_DIR/westley -m 128M
  cf push max-$suffix -p $APPS_DIR/max -m 512M
  cf push buttercup-$suffix -p $APPS_DIR/princess -m 1024M
  cf push humperdink-$suffix -p $APPS_DIR/humperdink -m 128M

  scale_up_start_time=$(date +%s)

  for i in `seq $scaling_iterations` ; do
    echo "[$suffix] Scaling apps, round $i..."

    cf scale humperdink-$suffix -i $(( 2*$i ))
    cf scale westley-$suffix -i $(( 8*$i ))
    cf scale max-$suffix -i $(( 4*$i ))
    cf scale buttercup-$suffix -i $(( 1*$i ))

    check_state westley-$suffix $(( 8*$i )) &> /dev/null
    check_state max-$suffix $(( 4*$i )) &> /dev/null
    check_state buttercup-$suffix $(( 1*$i )) &> /dev/null
  done

  scale_up_end_time=$(date +%s)

  echo "[$suffix] Sleeping for 1 minute..."
  sleep 60

  scale_down_start_time=$(date +%s)

  echo "[$suffix] Deleting the apps..."
  cf d -f humperdink-$suffix
  cf d -f westley-$suffix
  cf d -f max-$suffix
  cf d -f buttercup-$suffix

  scale_down_end_time=$(date +%s)

  echo "$scale_up_start_time,$scale_up_end_time,$scale_down_start_time,$scale_down_end_time" >> $results_file

  echo "[$suffix] Sleeping for 30 seconds..."
  sleep 30
done

