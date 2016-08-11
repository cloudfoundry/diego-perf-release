package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"math"
	"os"
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
	appPayload       = flag.String("payload", "assets/temp-app", "directory containing the stress-app payload to push")
	tolerance        = flag.Float64("tolerance", 1.0, "fractional failure tolerance")
)

type appDefinition struct {
	ManifestPath  string `json:"manifestPath"`
	AppNamePrefix string `json:"appNamePrefix"`
	AppCount      int    `json:"appCount"`
}

var seedApps []*cfApp
var appTypes *[]appDefinition
var totalAppCount int
var maxFailures int

func main() {
	cflager.AddFlags(flag.CommandLine)

	flag.Parse()

	logger, _ := cflager.New("cedar")
	logger.Info("started")
	defer logger.Info("exited")

	readConfig(logger)

	totalAppCount = 0

	for _, appDef := range *appTypes {
		totalAppCount += appDef.AppCount
	}
	totalAppCount = *numBatches * totalAppCount
	maxFailures = int(math.Ceil(*tolerance * float64(totalAppCount)))

	errChan := make(chan error, maxFailures)

	pushApps(logger, errChan)
	startApps(logger, errChan)
}

func pushApps(logger lager.Logger, errChan chan error) {
	logger = logger.Session("pushing-apps", lager.Data{"max-failures": maxFailures})
	logger.Info("started")
	defer logger.Info("complete")

	wg := sync.WaitGroup{}
	rateLimiter := make(chan struct{}, *maxInFlight)

	for i := 0; i < *numBatches; i++ {
		for _, appDef := range *appTypes {
			for j := 0; j < appDef.AppCount; j++ {
				seedApp := newCfApp(logger, fmt.Sprintf("%s-batch%d-%d", appDef.AppNamePrefix, i, j), *domain, *maxPollingErrors, appDef.ManifestPath)

				wg.Add(1)

				go func() {
					rateLimiter <- struct{}{}
					defer func() {
						<-rateLimiter
						wg.Done()
					}()

					err := seedApp.Push(logger, *appPayload)

					if err != nil {
						logger.Error("failed-pushing-app", err, lager.Data{"total-errors": len(errChan)})
						select {
						case errChan <- err:
						default:
							logger.Error("failure-tolerance-reached", nil)
							os.Exit(1)
						}
					}

					seedApps = append(seedApps, seedApp)
				}()
			}
		}
	}
	wg.Wait()
}

func startApps(logger lager.Logger, errChan chan error) {
	logger = logger.Session("starting-apps", lager.Data{"max-failures": maxFailures})
	logger.Info("started")
	defer logger.Info("completed")

	wg := sync.WaitGroup{}
	rateLimiter := make(chan struct{}, *maxInFlight)

	for i := 0; i < len(seedApps); i++ {
		appToPush := seedApps[i]

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
