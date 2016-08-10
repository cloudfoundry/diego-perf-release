package main

import (
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
	cfRetries        = flag.Int("cf-retries", 3, "maximum number of tries for a single cf command")
)

var tempApps []*cfApp
var appTypes []appDefinition
var totalAppCount int

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

	appTypes = []appDefinition{
		appDefinition{manifestPath: "assets/manifests/manifest-light.yml", appCount: 9, appNamePrefix: "light"},
		appDefinition{manifestPath: "assets/manifests/manifest-light-group.yml", appCount: 1, appNamePrefix: "light-group"},
		appDefinition{manifestPath: "assets/manifests/manifest-medium.yml", appCount: 7, appNamePrefix: "medium"},
		appDefinition{manifestPath: "assets/manifests/manifest-medium-group.yml", appCount: 1, appNamePrefix: "medium-group"},
		appDefinition{manifestPath: "assets/manifests/manifest-heavy.yml", appCount: 1, appNamePrefix: "heavy"},
		appDefinition{manifestPath: "assets/manifests/manifest-crashing.yml", appCount: 2, appNamePrefix: "crashing"},
	}

	totalAppCount = 0
	for _, appDef := range appTypes {
		totalAppCount += appDef.appCount
	}

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

	errChan := make(chan error, *numBatches*totalAppCount)
	wg := sync.WaitGroup{}
	rateLimiter := make(chan struct{}, *maxInFlight)

	for i := 0; i < *numBatches; i++ {
		for _, appDef := range appTypes {
			for j := 0; j < appDef.appCount; j++ {
				tempApp := newCfApp(logger, fmt.Sprintf("%s-batch%d-%d", appDef.appNamePrefix, i, j), *domain, *maxPollingErrors, appDef.manifestPath)

				wg.Add(1)

				go func() {
					rateLimiter <- struct{}{}
					defer func() {
						<-rateLimiter
						wg.Done()
					}()

					var err error
					for tries := *cfRetries; tries > 0; tries-- {

						err = tempApp.Push(logger)

						if err != nil {
							logger.Error("failed-pushing-app", err, lager.Data{"attempt": *cfRetries - tries + 1})
							continue
						}

						tempApps = append(tempApps, tempApp)
						logger.Debug("successful-push")
						break
					}

					if err != nil {
						logger.Error("giving-up-pushing-app", nil)
						errChan <- err
						os.Exit(1)
					}
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

	errChan := make(chan error, *numBatches*totalAppCount)
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

			var err error
			for tries := *cfRetries; tries > 0; tries-- {

				err = appToPush.Start(logger)

				if err != nil {
					logger.Error("failed-starting-app", err, lager.Data{"attempt": *cfRetries - tries + 1})
					continue
				}

				logger.Debug("successful-start")
				break
			}

			if err != nil {
				logger.Error("giving-up-starting-app", nil)
				errChan <- err
				os.Exit(1)
			}
		}()
	}
	wg.Wait()
}
