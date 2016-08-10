package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"sync"

	"code.cloudfoundry.org/cflager"
	"code.cloudfoundry.org/lager"
)

var (
	numBatches       = flag.Int("n", 0, "number of batches to seed")
	maxInFlight      = flag.Int("k", 1, "max number of cf operations in flight")
	domain           = flag.String("domain", "bosh-lite.com", "app domain")
	maxPollingErrors = flag.Int("max-polling-errors", 1, "max number of curl failures")
	configFile       = flag.String("config", "config.json", "path to cedar config file")
)

type appDefinition struct {
	ManifestPath  string `json:"manifestPath"`
	AppNamePrefix string `json:"appNamePrefix"`
	AppCount      int    `json:"appCount"`
}

var tempApps []*cfApp
var appTypes *[]appDefinition

func main() {
	cflager.AddFlags(flag.CommandLine)

	flag.Parse()

	logger, _ := cflager.New("cedar")
	logger.Info("started")
	defer logger.Info("exited")

	readConfig(logger)

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
	defer logger.Info("complete")

	wg := sync.WaitGroup{}
	rateLimiter := make(chan struct{}, *maxInFlight)

	for i := 0; i < *numBatches; i++ {
		for _, appDef := range *appTypes {
			for j := 0; j < appDef.AppCount; j++ {
				tempApp := newCfApp(logger, fmt.Sprintf("%s-batch%d-%d", appDef.AppNamePrefix, i, j), *domain, *maxPollingErrors, appDef.ManifestPath)

				wg.Add(1)

				go func() {
					rateLimiter <- struct{}{}
					defer func() {
						<-rateLimiter
						wg.Done()
					}()

					err := tempApp.Push(logger)

					if err != nil {
						logger.Error("failed-pushing-app", err)
						os.Exit(1)
					}

					tempApps = append(tempApps, tempApp)
				}()
			}
		}
	}
	wg.Wait()
}

func startApps(logger lager.Logger) {
	logger = logger.Session("starting-apps")
	logger.Info("started")
	defer logger.Info("completed")

	wg := sync.WaitGroup{}
	rateLimiter := make(chan struct{}, *maxInFlight)

	for i := 0; i < len(tempApps); i++ {
		appToPush := tempApps[i]

		wg.Add(1)

		go func() {
			rateLimiter <- struct{}{}
			defer func() {
				<-rateLimiter
				wg.Done()
			}()

			err := appToPush.Start(logger)

			if err != nil {
				logger.Error("failed-starting-app", err)
				os.Exit(1)
			}
		}()
	}
	wg.Wait()
}

func readConfig(logger lager.Logger) {
	conf, err := os.Open(*configFile)
	defer conf.Close()

	if err != nil {
		logger.Error("error-opening-config-file", err)
		os.Exit(1)
	}

	jsonParser := json.NewDecoder(conf)
	if err = jsonParser.Decode(&appTypes); err != nil {
		logger.Error("error-parsing-config-file", err)
		os.Exit(1)
	}
}
