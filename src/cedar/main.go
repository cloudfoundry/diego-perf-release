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
	manifestPath     = flag.String("manifest", "assets/stress-app/manifest.yml", "path of the manifest file")
	appPrefix        = flag.String("app-prefix", "light", "name prefix of the applications")
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
	pushApps(logger)
	startApps(logger)
}

func compileApp(logger lager.Logger) {
	logger = logger.Session("precompiling-test-app-binary")
	logger.Info("started")
	defer logger.Info("completed")

	os.Setenv("GOOS", "linux")
	os.Setenv("GOARCH", "amd64")
	os.Chdir("assets/stress-app")
	buildCmd := exec.Command("go", "build", "-o", "../temp-app/stress-app")
	err := buildCmd.Run()
	if err != nil {
		logger.Error("failed-building-test-app", err)
		os.Exit(1)
	}
	os.Chdir("../..")
}

func pushApps(logger lager.Logger) {
	logger = logger.Session("pushing-apps")
	logger.Info("started")
	defer logger.Info("completed")

	for i := 0; i < *numCopies; i++ {
		tempApp := newCfApp(logger, fmt.Sprintf("%s-%d", *appPrefix, i), *domain, *maxPollingErrors)
		tempApp.Push(logger, *manifestPath)
		tempApps = append(tempApps, tempApp)
	}
}

func startApps(logger lager.Logger) {
	logger = logger.Session("starting-apps")
	logger.Info("started")
	defer logger.Info("completed")

	for i := 0; i < *numCopies; i++ {
		tempApps[i].Start(logger)
	}
}
