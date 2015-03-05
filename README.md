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
1. Output is stored in `/var/vcap/packages/fezzik/src/github.com/cloudfoundry-incubator/fezzik/results.json`

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

## Development

These tests are meant to be run against a real IaaS. However, it is possible to
run them against BOSH-Lite during development. A deployment manifest template is
in `templates/bosh-lite.yml`. Use
[spiff](https://github.com/cloudfoundry-incubator/spiff) to merge it with a
`director_uuid` stub.
