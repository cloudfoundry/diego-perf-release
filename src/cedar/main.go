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
	numBatches       = flag.Int("n", 0, "number of batches to seed")
	domain           = flag.String("domain", "bosh-lite.com", "app domain")
	maxPollingErrors = flag.Int("max-polling-errors", 1, "max number of curl failures")
)

var tempApps []*cfApp

type appDefinition struct {
	manifestPath  string
	appNamePrefix string
	appCount      int
}

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

	appTypes := []appDefinition{
		appDefinition{manifestPath: "assets/manifests/manifest-light.yml", appCount: 9, appNamePrefix: "light"},
		appDefinition{manifestPath: "assets/manifests/manifest-light-group.yml", appCount: 1, appNamePrefix: "light-group"},
		appDefinition{manifestPath: "assets/manifests/manifest-medium.yml", appCount: 7, appNamePrefix: "medium"},
		appDefinition{manifestPath: "assets/manifests/manifest-medium-group.yml", appCount: 1, appNamePrefix: "medium-group"},
		appDefinition{manifestPath: "assets/manifests/manifest-heavy.yml", appCount: 1, appNamePrefix: "heavy"},
		appDefinition{manifestPath: "assets/manifests/manifest-crashing.yml", appCount: 2, appNamePrefix: "crashing"},
	}

	for i := 1; i <= *numBatches; i++ {
		for _, appDef := range appTypes {
			for j := 0; j < appDef.appCount; j++ {
				tempApp := newCfApp(logger, fmt.Sprintf("%s-batch%d-%d", appDef.appNamePrefix, i, j), *domain, *maxPollingErrors)
				tempApp.Push(logger, appDef.manifestPath)
				tempApps = append(tempApps, tempApp)
			}
		}
	}
}

func startApps(logger lager.Logger) {
	logger = logger.Session("starting-apps")
	logger.Info("started")
	defer logger.Info("completed")

	for i := 0; i < len(tempApps); i++ {
		tempApps[i].Start(logger)
	}
}
