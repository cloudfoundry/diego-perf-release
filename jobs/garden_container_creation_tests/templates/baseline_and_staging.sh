#!/bin/bash

set -xe

if [ $# != 4 ]; then
  echo "Usage: $(basename $0) SUFFIX NUM SCALING_ITERATIONS LOGS_DIR"
  echo
  echo "Will deploy four apps, scale them up, and repeat NUM times"
  exit 2
fi

suffix=$1
numtimes=$2
scaling_iterations=$3
logs_dir=$4

check_state() {
  name=$1
  instances=$2

  start_time=`date +%s`
  current_time=`date +%s`
  while [ $((current_time - start_time)) -lt 600 ] ; do
    if [[ $(cf app $name | grep "#" | egrep -v "(starting|stopped)" | wc -l) -eq $instances ]]; then
      return
    fi
    current_time=`date +%s`
  done
  exit 1
}

APPS_DIR=/var/vcap/packages/stress_tests/src/github.com/cloudfoundry-incubator/diego-stress-tests/assets/apps

echo "Pushing baseline apps (westley and humperdink)"
cf push base-humperdink-$suffix -p $APPS_DIR/humperdink -m 128M -i 3 >> $logs_dir/cf.log
cf push base-westley-$suffix -p $APPS_DIR/westley -m 128M >> $logs_dir/cf.log

echo "Scaling up westley"
for i in `seq $scaling_iterations`; do
  cf scale base-westley-$suffix -i $(( 5*$i )) >> $logs_dir/cf.log
  check_state base-westley-$suffix $(( 5*$i )) >> $logs_dir/cf.log
done


echo "Starting and deleting $numtimes*3 stagings of max"
for i in `seq $numtimes`; do
  ( cf push max1-$suffix -p $APPS_DIR/max -m 512M >> $logs_dir/max1.log ) &
  ( cf push max2-$suffix -p $APPS_DIR/max -m 512M >> $logs_dir/max2.log ) &
  ( cf push max3-$suffix -p $APPS_DIR/max -m 512M >> $logs_dir/max3.log ) &
  check_state max1-$suffix 1 >> $logs_dir/max1.log
  check_state max2-$suffix 1 >> $logs_dir/max2.log
  check_state max3-$suffix 1 >> $logs_dir/max3.log
  sleep 2
  cf d -f max1-$suffix >> $logs_dir/max1.log
  cf d -f max2-$suffix >> $logs_dir/max2.log
  cf d -f max3-$suffix >> $logs_dir/max3.log
done

