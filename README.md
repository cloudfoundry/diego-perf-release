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

### Run Cedar from a Bosh deployment (single pusher stress test)

1. Run `./scripts/generate-bosh-lite-manifests` and deploy `diego-perf-release` with the generated manifest
1. Do a `bosh ssh` into the `diego-perf` deployment
1. Run `sudo su` and navigate to `/var/vcap/packages/cedar`
1. Run `/var/vcap/jobs/cedar/bin/cedar_script`
1. Find the logs in `/var/vcap/sys/log/cedar/cedar.stdout.log`
1. (Optional) edit the script under `/var/vcap/jobs/cedar/bin/cedar_script` to pass in custom flags to cedar

### Run Cedar locally (single pusher stress test)

1. Make sure you're targeting a default diego enabled backend CF deployment
1. Target a chosen org and space
1. cd src/code.cloudfoundry.org/diego-stress-tests/cedar/assets/stress-app
1. Precompile the stress-app to `assets/temp-app` by running `GOOS=linux GOARCH=amd64 go build -o ../temp-app/stress-app`
1. cd back to src/cedar
1. Build the cedar binary with `go build`
1. Run the following to start a test
```bash
./cedar -n 2 -k 2 [-config <path-to-config.json-file>] [-payload <path-to-dir-containing-app-payload>] [-domain <your-app-domain>] [-tolerance <tolerance-factor>]
```
Where:
- `n` is the number of desired batches of apps described by the config file that will be seeded
- `k` is the max number of cf operations in flight.
- `config` if not specified will default to `./config.json` which reflects the mix of apps specified in the [performance protocol](https://github.com/cloudfoundry/diego-dev-notes/blob/master/proposals/measuring_performance.md#experiment-2-launching-and-running-many-cf-applications).
- `payload` if not specified will default to `assets/temp-app` which should only contain the precompiled binary generated above.
- `domain` if not specified will default to `bosh-lite.com`.
- `tolerance` is the ratio of apps the are allowed to fail, before Cedar terminates. If not specified, it defaults to `1.0`, i.e. deploys all apps and does not fail due to app failures.
- `timeout` is the amount of time to wait for each cf command to succeed when pushing and starting apps. The default value is `30 seconds`
- `output` is the path to the file where the report output from `cedar` will be stored. The default location is `$PWD/output.json`

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

## Development

These tests are meant to be run against a real IaaS. However, it is possible to
run them against BOSH-Lite during development. A deployment manifest template is
in `templates/bosh-lite.yml`. Use
[spiff](https://github.com/cloudfoundry-incubator/spiff) to merge it with a
`director_uuid` stub.
