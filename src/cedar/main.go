package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"

	"code.cloudfoundry.org/cflager"
	"code.cloudfoundry.org/lager"
)

var (
	numCopies        = flag.Int("n", 0, "number of copies to seed")
	domain           = flag.String("domain", "bosh-lite.com", "app domain")
	maxPollingErrors = flag.Int("max-polling-errors", 1, "max number of curl failures")
)

var masterApp *cfApp
var tempApps []*cfApp

func main() {
	cflager.AddFlags(flag.CommandLine)

	flag.Parse()

	logger, _ := cflager.New("cedar")
	logger.Info("started")
	defer logger.Info("exited")

	compileApp(logger)
	pushMaster(logger)
	pushTargetApps(logger)
	copySeedBits(logger)
	startSeedApps(logger)
}

func compileApp(logger lager.Logger) {
	logger = logger.Session("precompiling-test-app-binary")
	logger.Info("started")
	defer logger.Info("completed")

	os.Setenv("GOOS", "linux")
	os.Setenv("GOARCH", "amd64")
	os.Chdir("assets/stress-app")
	buildCmd := exec.Command("go", "build", ".")
	err := buildCmd.Run()
	if err != nil {
		logger.Error("failed-building-test-app", err)
		os.Exit(1)
	}
	os.Chdir("../..")
}

func pushMaster(logger lager.Logger) {
	logger = logger.Session("pushing-master-apps")
	logger.Info("started")
	defer logger.Info("completed")

	masterApp = newCfApp(logger, "light-master", *domain, *maxPollingErrors)
	masterApp.PushMaster(logger)
}

func pushTargetApps(logger lager.Logger) {
	logger = logger.Session("pushing-target-apps")
	logger.Info("started")
	defer logger.Info("completed")

	for i := 0; i < *numCopies; i++ {
		tempApp := newCfApp(logger, fmt.Sprintf("light-copy-%d", i), *domain, *maxPollingErrors)
		tempApp.Push(logger)
		tempApps = append(tempApps, tempApp)
	}
}

func copySeedBits(logger lager.Logger) {
	logger = logger.Session("copying-seed-bits")
	for i := 0; i < *numCopies; i++ {
		masterApp.CopyBitsTo(logger, tempApps[i])
	}
}

func startSeedApps(logger lager.Logger) {
	logger = logger.Session("starting-apps")
	logger.Info("started")
	defer logger.Info("completed")

	for i := 0; i < *numCopies; i++ {
		tempApps[i].Start(logger)
	}
}
