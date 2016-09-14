#!/usr/bin/env bash

# ## How to use this script
# ### Assumptions:
#     1. You have port 8086 forwarded on the local machine to influxdb
#        ssh -L 8086:PRIVATE_IP_OF_INFLUX:8086 -i keypair -N vcap@HOST_OF_BOSH_DIRECTOR &
#     2. You are bosh targeted to the right environment
#     3. You ran `bosh deployment` to set the deployment manifest to perf.yml
# ### Generating percentiles for a given batch
#     1. Create batch-<start>-<end> directory (.e.g batch-1-20, batch-21-40, etc.)
#     2. From that directory run `/path/to/cedar_results.sh <min> <max> output.json`
#     3. Repeat 10 times

if [ $# -lt 2 ]; then
    echo "Usage: $0 star-time end-time [output-file]"
    exit 1
fi

min=${1}
max=${2}

min=$(( min - 1 ))
max=$(( max + 1 ))

export output=""
if [ $# -gt 2 ]; then
    output=$3
    rm $output
fi

function getlogs {
    job=$1
    name=$(echo $job | cut -d/ -f1)
    index=$(echo $job | cut -d/ -f2)
    dir=$name-$index

    if [ -d $dir ]; then
        return 0
    fi

    mkdir $dir
    pushd $dir
      bosh logs $name $index
      tar -xf *
    popd
}

function download_logs {
    vms=$(bosh vms)
    for job in $(echo "$vms" | grep cedar | awk '{print $2}'); do
        getlogs $job
    done
}

function generate_metrics {
    find . -name *.gz -exec gunzip {} \;
    veritas chug-unify -min $min -max $max **/**/*.log* > unified.log
    cat unified.log | perfchug > influx-input.log
}

function load_metrics {
    curl -i -XPOST 'http://localhost:8086/query' --data-urlencode 'q=DROP DATABASE cfperf'
    curl -i -XPOST 'http://localhost:8086/query' --data-urlencode 'q=CREATE DATABASE cfperf'
    curl -i -XPOST 'http://localhost:8086/write?db=cfperf' --data-binary @influx-input.log
}

function query_influxdb {
    db=$1
    query=$2
    echo
    if [ "x$output" == "x" ]; then
        curl --silent -XPOST "http://localhost:8086/query?db=$db" --data-urlencode "q=$query"
    else
        echo "Running $query"
        echo >> $output
        curl --silent -XPOST "http://localhost:8086/query?db=$db" --data-urlencode "q=$query" >> $output
    fi
}

function query_metrics {
    scale=1000000000
    percentiles="percentile(value, 99)/$scale AS percentile_99, percentile(value, 95)/$scale AS percentile_95, percentile(value, 90)/$scale AS percentile_90, percentile(value, 50)/$scale AS percentile_50, percentile(value, 10)/$scale AS percentile_10"
    where_clause="where time > ${min}000000000 AND time < ${max}000000000"

    # pending story https://www.pivotaltracker.com/story/show/126888429
    query_influxdb "cfperf" "select $percentiles from \"cf.diego.CedarSuccessfulStart\" $where_clause"
    query_influxdb "cfperf" "select count(value) from \"cf.diego.CedarSuccessfulStart\" $where_clause"
    query_influxdb "cfperf" "select $percentiles from \"cf.diego.CedarFailedStart\" $where_clause"
    query_influxdb "cfperf" "select count(value) from \"cf.diego.CedarFailedStart\" $where_clause"
    query_influxdb "cfperf" "select $percentiles from \"cf.diego.CedarSuccessfulPush\" $where_clause"
    query_influxdb "cfperf" "select count(value) from \"cf.diego.CedarSuccessfulPush\" $where_clause"
    query_influxdb "cfperf" "select $percentiles from \"cf.diego.CedarFailedPush\" $where_clause"
    query_influxdb "cfperf" "select count(value) from \"cf.diego.CedarFailedPush\" $where_clause"

}

download_logs
generate_metrics
load_metrics
query_metrics

echo "$@" > cmd-args.txt
