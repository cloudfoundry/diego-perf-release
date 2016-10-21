# BOSH Diego Performance Release

This is a release to measure the performance of Diego. See the proposal [here](https://github.com/pivotal-cf-experimental/diego-dev-notes/blob/master/proposals/measuring_performance.md).

## Usage

### Prerequisites

Deploy diego-release, cf-release.  To deploy this release, create a BOSH
deployment manifest with as many pusher instances as you want to use for
testing.

### Running Fezzik

1. `bosh ssh stress_tests 0`
1. Run `/var/vcap/jobs/caddy/bin/1_fezzik` multiple times.
1. Output is stored in `/var/vcap/packages/fezzik/src/github.com/cloudfoundry-incubator/fezzik/reports.json`


### Running Cedar

#### Automatically Running 10 Batches of Cedar (Preferred)

The steps mentioned in the previous section are automated by the
`./cedar_script`. The script will push 10 batches of apps each in its own
spaces. Details below on how to run it:

1. Run `cd /var/vcap/jobs/cedar/bin`.
1. Run the following command to run the experiment:
    ```bash
    ./cedar_script
    ```
1. To resume the experiment from the `n`th batch (where `n` is a number from `1`
  to `10`), add `n` as an argument to the script. For example, to run from the
  fourth batch:
  ```bash
  ./cedar_script 4
  ```

 **Note**: if the spaces are already present from a previous run of the script,
 the script will not fail and will instead continue to push to those existing
 spaces. Manually delete spaces or the entire CF org if required.


This script also then pushes an extra batch of apps via `cedar`
and monitors them with `arborist`. The file
`/var/vcap/sys/log/cedar/cedar-arborist-output.json`
contains the results from that `cedar` run, and the file
`/var/vcap/sys/log/arborist/arborist-output.json`
contains the `arborist` results.

The script will also output the min/max timestamp for each batch in
`/var/vcap/data/cedar/min-<batch#>.json` and
`/var/vcap/data/cedar/max-<batch#>.json`.


#### Running Cedar from a BOSH deployment

1. Run `./scripts/generate-deployment-manifest` and deploy `diego-perf-release`
   with the generated manifest. If on BOSH-Lite, you can use
   `./scripts/generate-bosh-lite-manifests`.
1. Run `bosh ssh` to SSH to the `cedar` VM in the `cf-warden-diego-perf` deployment.
1. Run `sudo su`.
1. Run the following commands:
   ```bash
   # put the CF CLI on the PATH
   export PATH=/var/vcap/packages/cf-cli/bin:$PATH

   # target CF and create an org and space for the apps
   cf api api.bosh-lite.com --skip-ssl-validation
   cf auth admin admin
   cf create-org o
   cf create-space cedar -o o
   cf target -o o -s cedar

   cd /var/vcap/packages/cedar

   /var/vcap/packages/cedar/bin/cedar \
     -n 1 \
     -k 2 \
     -payload /var/vcap/packages/cedar/assets/temp-app \
     -config /var/vcap/packages/cedar/config.json \
     -domain bosh-lite.com \
     &
   ```

#### Running Cedar Locally

1. Target a CF deployment.
1. Target a chosen org and space.
1. From the root of this repo, run `cd src/code.cloudfoundry.org/diego-stress-tests/cedar/assets/stress-app`.
1. Precompile the stress-app to `assets/temp-app` by running `GOOS=linux GOARCH=amd64 go build -o ../temp-app/stress-app`.
1. Run `cd ../..` to change back to `src/code.cloudfoundry.org/diego-stress-tests/cedar`.
1. Run `go build` to build the `cedar` binary.
1. Run the following to start a test:
  ```bash
  ./cedar -n <number_of_batches> -k <max_in_flight> [-tolerance <tolerance-factor>]
  ```

Run `./cedar -h` to see the list of options you can provide to cedar.
One of the most important options is a JSON-encoded config file that
provides the manifest paths for the different apps being pushed. The
default `config.json` can be found
[here](https://github.com/cloudfoundry/diego-stress-tests/blob/master/cedar/config.json).


### Run Arborist from a BOSH deployment

Note: Arborist depends on a successful `cedar` run, as it uses the output file from
`cedar` as an input.

Run the example below to monitor apps on a BOSH-Lite installation:

1. Run `./scripts/generate-bosh-lite-manifests` and deploy `diego-perf-release` with the generated manifest.
1. Run `bosh ssh` to SSH to the `cedar` VM in the `cf-warden-diego-perf` deployment.
1. Run `sudo su`.
1. Run the following commands to run `arborist` from a tmux session:
  ```bash
  # start a new tmux session
  /var/vcap/packages/tmux/bin/tmux new -s arborist

  cd /var/vcap/packages/arborist

  /var/vcap/packages/arborist/bin/arborist \
    -app-file <cedar-output-file> \
    -duration 10m \
    -logLevel info \
    -request-interval 10s \
    -result-file output.json &
  ```
1. To detach from the `tmux` session, send `Ctrl-b d`.
1. To reattach to the `tmux` session, run `/var/vcap/packages/tmux/bin/tmux attach -t arborist`.

### Run Arborist Locally

1. cd to `src/code.cloudfoundry.org/diego-stress-tests/arborist`
1. Build the arborist binary with `go build`.

1. Run the following to start a test:
  ```bash
  ./arborist \
    -app-file <cedar-output-file> \
    -duration 10m \
    -logLevel info \
    -request-interval 10s \
    -result-file output.json
  ```

Arborist has the following usage options:

```
  -app-file string
        path to json application file
  -domain string
        domain where the applications are deployed (default "bosh-lite.com")
  -duration duration
        total duration to check routability of applications (default 10m0s)
  -logLevel string
        log level: debug, info, error or fatal (default "info")
  -request-interval duration
        interval in seconds at which to make requests to each individual app (default 1m0s)
  -result-file string
        path to result file (default "output.json")
```


### Monitoring the cluster

The team has created three grafana dashboards that include graphs to monitor
interesting metrics. Below are the names and description of each one of those
dashboards:

- `aggregation/bosh_influxdb_dashboard.json`

  System metrics (i.e. cpu usage, system load and disk usage) across the entire cluster

- `aggregation/diego_influxdb_dashboard.json`

  Diego metrics, e.g. bbs api latency, bbs requests/s, etc.

- `aggregation/golang_stats_influxdb_dashboard.json`

  Golang metrics (i.e. number of goroutines, gc pause, etc.)

#### Importing dashboard

To import any/all of those dashboards. From the home page:

1. Click on `Home` (or the dashboard search dropdown)
2. Click on `Import`
3. Choose a file
4. Save the dashboard (`CTRL+S` or the drive icon next to the dashboard dropdown)

See [grafana export/import doc] for more info

#### Exporting dashboard

To export a dashboard after editing it, do the following:

1. Go to the dashboard you want to export (by clicking the name in the dashboard dropdown)
2. Click the `Manage dashboard` button (the gear icon next to the dashboard dropdown)
3. Click `Export`
4. Grafan will automatically download the json file

See [grafana export/import doc] for more info

### Aggregating results

#### Preprocessing using perfchug

`perfchug` is a tool that ships with the diego-perf-release. It takes log
output from cedar, bbs and auctioneer, processes it, and converts it into
something that can be fed into InfluxDB.

To use `perfchug` locally:

1. `cd <path>/diego-perf-release/src/code.cloudfoundry.org/diego-stress-tests/perfchug`.
1. Run `go install` to build the executable.
1. Move the executable into your `$PATH`.

Once on the `$PATH`, supply lager-formatted logs to `perfchug` on its stdin.

For example:

```bash
cat /var/vcap/sys/log/cedar/cedar.stdout.log | perfchug
```

will emit influxdb-formatted metrics to stdout.

#### Automatic downloading and aggregation

We wrote a script to automate the entire process. The script does the following:

1. Download brain, bbs & cedar job logs using bosh
1. Reduce the logs to the start/end timestamps of the experiments ran
1. Merge the logs from all jobs together
1. Run perfchug on the resulting log file
1. Insert the output of perfchug into influxdb
1. Run a fixed set of queries to get percentiles of requests latency among other interesting metrics

In order to use the script, you need to do the following:

1. You are on a jump box inside the deployment, e.g. director
1. You are bosh targeted to the right environment
1. You have perfchug, veritas and bosh on your PATH
1. Create a new directory and `cd` into it. This will be used as the working
   directory for the script. BOSH logs will be downloaded in this directory.

1. From that directory run:
  ```bash
  /path/to/diego_results.sh \
    http://url.to.influxdb:8086 \
    /path/to/diego/manifest \
    /path/to/perf/manifest \
    [/path/to/output/file]\
  ```

The output file will contain one line per query. All query results are valid
json. If there are no data points in InfluxDB, e.g. no failures, InfluxDB will
result an empty result, e.g. `{"results":[]}`

If the output file parameter is provided, `diego_results.sh` will also trigger
a post-processing script that condenses the output into `metrics.csv`, a more
human-readable format.


#### Snapshotting and Restoring Influxdb (GCP Only)

##### Snapshotting

1. Go to the google cloud platform dashboard, and find the influxdb instance.
1. Find the 'additional disks' section, and click on the disk to be snapshotted.
1. Click 'Create Snapshot' at the top of the window that opens up.
1. Name the snapshot and click 'Create'.

##### Restoring a snapshotted InfluxDB

1. Go to the google cloud platform dashboard, and find the influxdb instance.
1. Click edit at the top of the page.
1. Find the 'additional disks' section, and add a disk from the snapshot.
1. Click save at the bottom of the page. The new disk will appear as /dev/sd[a-z] (where [a-z] is the next available letter for a disk name).
1. Edit `/etc/mtab` on the influxdb vm to add the new filesystem from `/dev/sd[a-z]` to `/var/vcap/store2`.
1. Run `mkdir -p /var/vcap/store2 && cd /var/vcap/store2 && mount /dev/sd[a-z]1`.
1. Edit all references to `/var/vcap/store` -> `/var/vcap/store2` in `/var/vcap/jobs/influxdb`.
1. Restart influxdb with `monit restart influxdb`.

## Development

These tests are meant to be run against a real IaaS. However, it is possible to
run them against BOSH-Lite during development. A deployment manifest template is
in `templates/bosh-lite.yml`. Use
[spiff](https://github.com/cloudfoundry-incubator/spiff) to merge it with a
`director_uuid` stub.

[grafana export/import doc]: http://docs.grafana.org/reference/export_import/
