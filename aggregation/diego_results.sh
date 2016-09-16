#!/usr/bin/env bash

set -e

if [ $# -lt 3 ]; then
    echo "Usage: $0 influxdb_url /path/to/diego/manifest /path/to/perf/manifest [output-file]"
    exit 1
fi

influxdb_url=$1
if [[ $influxdb_url != */ ]]; then
    influxdb_url=${influxdb_url}/
fi
diego_manifest=$2
perf_manifest=$3

export output=""
if [ $# -gt 3 ]; then
    output=$4
    [ -x $output ] && rm $output
fi

function getlogs {
    job=$1
    manifest=$2
    name=$(echo $job | cut -d/ -f1)
    index=$(echo $job | cut -d/ -f2)
    dir=$name-$index

    if [ -d $dir ]; then
        return 0
    fi

    mkdir $dir
    pushd $dir
      bosh -d $manifest logs $name $index
      tar -xf *
    popd
}

function download_logs {
    jobName=$1
    manifest=$2
    vms=$(bosh -d $manifest vms)
    for job in $(echo "$vms" | grep $jobName | awk '{print $2}'); do
        getlogs $job $manifest
    done
}

function generate_metrics {
    min=$1
    max=$2
    find . -name *.gz -exec gunzip {} \;
    veritas chug-unify -min $min -max $max $(find . -name \*.log\*) > unified.log
    cat unified.log | perfchug > influx-input.log
}

function load_metrics {
    curl -i -XPOST "${influxdb_url}query" --data-urlencode 'q=DROP DATABASE cfperf'
    curl -i -XPOST "${influxdb_url}query" --data-urlencode 'q=CREATE DATABASE cfperf'
    curl -i -XPOST "${influxdb_url}write?db=cfperf" --data-binary @influx-input.log
}

function query_influxdb {
    db=$1
    query=$2
    echo
    if [ "x$output" == "x" ]; then
        curl --silent -XPOST "${influxdb_url}query?db=$db" --data-urlencode "q=$query"
    else
        echo "Running $query"
        echo >> $output
        curl --silent -XPOST "${influxdb_url}query?db=$db" --data-urlencode "q=$query" >> $output
    fi
}

function query_metrics {
    min=$1
    max=$2
    scale=1000000000
    percentiles="percentile(value, 99)/$scale AS percentile_99, percentile(value, 95)/$scale AS percentile_95, percentile(value, 90)/$scale AS percentile_90, percentile(value, 50)/$scale AS percentile_50, percentile(value, 10)/$scale AS percentile_10"
    where_clause="where time > ${min}000000000 AND time < ${max}000000000"

    # pending story https://www.pivotaltracker.com/story/show/126888429
    query_influxdb "cfperf" "select $percentiles from \"cf.diego.RequestLatency\" $where_clause group by component, request"
    query_influxdb "cfperf" "select count(value) from \"cf.diego.RequestLatency\" $where_clause group by component, request"
    query_influxdb "cfperf" "select $percentiles from \"cf.diego.AuctionScheduleDuration\" $where_clause"
    query_influxdb "cfperf" "select count(value) from \"cf.diego.AuctionScheduleDuration\" $where_clause"
    query_influxdb "cfperf" "select $percentiles from \"cf.diego.TaskLifecycle\" $where_clause"
    query_influxdb "cfperf" "select count(value) from \"cf.diego.TaskLifecycle\" $where_clause"
    query_influxdb "cfperf" "select $percentiles from \"cf.diego.LRPLifecycle\" $where_clause"
    query_influxdb "cfperf" "select count(value) from \"cf.diego.LRPLifecycle\" $where_clause"

    query_influxdb "cfperf" "select $percentiles from \"cf.diego.CedarSuccessfulStart\" $where_clause"
    query_influxdb "cfperf" "select count(value) from \"cf.diego.CedarSuccessfulStart\" $where_clause"
    query_influxdb "cfperf" "select $percentiles from \"cf.diego.CedarFailedStart\" $where_clause"
    query_influxdb "cfperf" "select count(value) from \"cf.diego.CedarFailedStart\" $where_clause"
    query_influxdb "cfperf" "select $percentiles from \"cf.diego.CedarSuccessfulPush\" $where_clause"
    query_influxdb "cfperf" "select count(value) from \"cf.diego.CedarSuccessfulPush\" $where_clause"
    query_influxdb "cfperf" "select $percentiles from \"cf.diego.CedarFailedPush\" $where_clause"
    query_influxdb "cfperf" "select count(value) from \"cf.diego.CedarFailedPush\" $where_clause"
}

function generate_metrics_for_all_batches {
    counter=1
    cedar_dir=./cedar-0/cedar
    while true; do
        min_file=$cedar_dir/min-$counter.json
        max_file=$cedar_dir/max-$counter.json
        if [ ! -r $min_file -o ! -r $max_file ]; then
            break
        fi
        min=$(cat $min_file)
        max=$(cat $max_file)
        echo "Generating metrics for $min < t < $max"
        generate_metrics $min $max
        load_metrics
        query_metrics $min $max
        let counter=counter+1
    done
}

download_logs brain $diego_manifest
download_logs database $diego_manifest
download_logs cedar $perf_manifest
generate_metrics_for_all_batches

echo "$@" > cmd-args.txt
