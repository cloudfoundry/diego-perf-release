# BOSH Diego Performance Release

This is a release to measure the performance of Diego. See the proposal [here](https://github.com/pivotal-cf-experimental/diego-dev-notes/blob/master/proposals/measuring_performance.md).

## Usage

### Prerequisites

Deploy diego-release, cf-release.  To deploy this release, create a BOSH
deployment manifest with as many pusher instances as you want to use for
testing.

### To Run Fezzik

1. `bosh ssh stress_tests 0`
1. Run `/var/vcap/jobs/caddy/bin/1_fezzik` multiple times.
1. Output is stored in `/var/vcap/packages/fezzik/src/github.com/cloudfoundry-incubator/fezzik/reports.json`

### Run Cedar from a BOSH deployment (single pusher stress test)

Run the example below to push apps on a BOSH-Lite installation:

1. Run `./scripts/generate-bosh-lite-manifests` and deploy `diego-perf-release` with the generated manifest.
1. Run `bosh ssh` to SSH to the `cedar` VM in the `cf-warden-diego-perf` deployment.
1. Run `sudo su`.
1. Run the following commands to run `cedar` from a tmux session:
  ```bash
  # start a new tmux session
  /var/vcap/packages/tmux/bin/tmux new -s cedar

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
1. To detach from the `tmux` session, send `Ctrl-b d`.
1. To reattach to the `tmux` session, run `/var/vcap/packages/tmux/bin/tmux attach -t cedar`.

### Run Cedar locally (single pusher stress test)

1. Target a default diego enabled CF deployment
1. Target a chosen org and space
1. cd src/code.cloudfoundry.org/diego-stress-tests/cedar/assets/stress-app
1. Precompile the stress-app to `assets/temp-app` by running `GOOS=linux GOARCH=amd64 go build -o ../temp-app/stress-app`
1. cd back to src/code.cloudfoundry.org/diego-stress-tests/cedar
1. Build the cedar binary with `go build`
1. Run the following to start a test
```bash
./cedar -n <number_of_batches> -k <max_in_flight> -domain <your-app-domain> [-tolerance <tolerance-factor>]
```

Cedar has the following usage options:

```
-config string
  path to cedar config file (default "config.json")
-domain string
  app domain (default "bosh-lite.com")
-k int
  max number of cf operations in flight (default 1)
-max-polling-errors int
  max number of curl failures (default 1)
-n int
  number of batches to seed (default 1)
-output string
  path to cedar metric results file (default "output.json")
-payload string
  directory containing the stress-app payload to push (default "assets/temp-app")
-prefix string
  the naming prefix for cedar generated apps (default "cedarapp")
-timeout int
  time allowed for a push or start operation , in seconds (default 30)
-tolerance float
  fractional failure tolerance (default 1)
```

Example `config.json` file:
```json
[
  {
    "manifestPath": "assets/manifests/manifest-light.yml",
    "appCount": 9,
    "appNamePrefix": "light"
  },
  {
    "manifestPath": "assets/manifests/manifest-light-group.yml",
    "appCount": 1,
    "appNamePrefix": "light-group"
  },
  {
    "manifestPath": "assets/manifests/manifest-medium.yml",
    "appCount": 7,
    "appNamePrefix": "medium"
  },
  {
    "manifestPath": "assets/manifests/manifest-medium-group.yml",
    "appCount": 1,
    "appNamePrefix": "medium-group"
  },
  {
    "manifestPath": "assets/manifests/manifest-heavy.yml",
    "appCount": 1,
    "appNamePrefix": "heavy"
  },
  {
    "manifestPath": "assets/manifests/manifest-crashing.yml",
    "appCount": 2,
    "appNamePrefix": "crashing"
  }
]
```

### Run Arborist from a BOSH deployment

Note: Arborist is dependant on a successful `cedar` as it uses the output file from
`cedar` as input.

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
    -domain bosh-lite.com \
    -duration 10m \
    -logLevel info \
    -request-interval 10s \
    -result-file output.json &
  ```
1. To detach from the `tmux` session, send `Ctrl-b d`.
1. To reattach to the `tmux` session, run `/var/vcap/packages/tmux/bin/tmux attach -t arborist`.

### Run Arborist locally

1. cd to src/code.cloudfoundry.org/diego-stress-tests/arborist
1. Build the arborist binary with `go build`
1. Run the following to start a test
```bash
./arborist -app-file <cedar-output-file> \
    -domain bosh-lite.com \
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

### Using perfchug to convert logs to InfluxDB records

`perfchug` is a tool that ships with the diego-perf-release. It takes log
output from cedar, among other things, processes it, and converts it into
something that can be fed into InfluxDB.

A `perfchug` binary is provided as part of the BOSH release. To use `perfchug`
locally:

1. `cd <path>/diego-perf-release/src/code.cloudfoundry.org/diego-stress-tests/perfchug`
1. Run `go build` to build the executable
1. Move the executable into your `$PATH`

Once it's in your path, you can use `perfchug` by piping log output into it.
For example:

```
./cedar -n 2 -k 2 | perfchug
```

will spit influxdb-friendly metrics to stdout.



### To Run Stress Tests

1. Simultaneously `bosh ssh stress_tests n`, where `n` is the index of the
   pusher
1. Run `/var/vcap/jobs/caddy/bin/2_stress_tests` simultaneously on each pusher
1. Output is stored in `/var/vcap/data/stress_tests/`.

#### Structure of the Stress Tests' Output

```
|- round-a-0/
|   |- push-westley-someguid      # all output from pushing the app, success/failure and duration
|   |- ...
|   |- curl-westley-someguid      # all output from curling the app, success/failure and duration
|   |- ...
|   |- log-westley-someguid      # all output from curling the app, success/failure and duration
|   |- ...
|- round-b-0/
|   |- ...
|- ...
```

### To Run Container Creation Tests

You need a CF and a Diego manifest from your deployment in the same directory,
they have to be named `cf-deployment.yml` and `diego-deployment.yml`
respectively. BOSH should already be targeted at your director.

```bash
git clone git@github.com:cloudfoundry-incubator/diego-perf-release ~/workspace/diego-perf-release
cd ~/workspace/diego-perf-release
./scripts/generate-deployment-manifest <stubs-path>/director-uuid.yml <stubs-path>/perf/property-overrides.yml <stubs-path>/perf/instance-count-overrides.yml <stubs-path>/perf/iaas-settings.yml <path-to-deployment-manifests> > <path-to-deployment-manifests>/perf-deployment.yml
bosh deployment <path-to-deployment-manifests>/perf-deployment.yml
bosh create release --force && bosh upload release && bosh -n deploy
bosh run errand garden_container_creation_tests --keep-alive
bosh logs garden_container_creation_tests # this will download results.csv.log, which is a csv file containing the timestamps for the pushes and scales.
```

In `stubs/perf/property-overrides.yml` you can set a few properties,
in particular `num_runs`. This tells the test how many times to repeat the cycle
of pushing and scaling the apps.

If you need extra info about your test run, check out `stdout.log`,
`stderr.log`, and `cf.log` from the `bosh logs` download.

You can also watch all of those files while running the errand by ssh'ing into
the errand VM.

Worth noting that there is a tmux binary installed on the errand VM at
`/var/vcap/packages/tmux/bin/tmux` if you need fancier shelling.

### To Run CF-based experiment

1. Run `./scripts/generate-deployment-manifest` and deploy `diego-perf-release` with the generated manifest. If on bosh-lite, you can use `./scripts/generate-bosh-lite-manifests`.
1. Run `bosh ssh` to SSH to the cedar VM in the diego-perf deployment.
1. Run `sudo su`.
1. Run `cd /var/vcap/jobs/cedar/bin`
1. Run the following command to run the experiment:
  ```
  ./cedar_script
  ```
  
  To delete the spaces from a previous experiment before running the experiment, run the script as:
  ```
  DELETE_SPACES="yes" ./cedar_script
  ```
  
  To resume the experiment from the `n`th batch (where `n` is a number from `1` to `10`), add `n` as an argument to the script. For example, to run from the fourth batch:
  ```
  ./cedar_script 4
  ```
  
  To see the results of the experiment, see the file `/var/vcap/data/sys/log/arborist/arborist-output.json`.


## Development

These tests are meant to be run against a real IaaS. However, it is possible to
run them against BOSH-Lite during development. A deployment manifest template is
in `templates/bosh-lite.yml`. Use
[spiff](https://github.com/cloudfoundry-incubator/spiff) to merge it with a
`director_uuid` stub.
