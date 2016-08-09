package cedar_test

import (
	"fmt"
	"io/ioutil"
	"net/http"
	"net/url"
	"time"

	"github.com/cloudfoundry-incubator/cf-test-helpers/cf"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gbytes"
	"github.com/onsi/gomega/gexec"
)

const (
	CFUser          = "admin"
	CFPassword      = "admin"
	AppRoutePattern = "http://%s.%s"
)

type cfApp struct {
	appName        string
	appRoute       url.URL
	attemptedCurls int
	failedCurls    int
	maxFailedCurls int
}

func newCfApp(appNamePrefix string, maxFailedCurls int) *cfApp {
	appName := appNamePrefix
	rawUrl := fmt.Sprintf(AppRoutePattern, appName, config.OverrideDomain)
	appUrl, err := url.Parse(rawUrl)
	if err != nil {
		panic(err)
	}
	return &cfApp{
		appName:        appName,
		appRoute:       *appUrl,
		maxFailedCurls: maxFailedCurls,
	}
}

func (a *cfApp) PushMaster() {
	// push master
	Eventually(cf.Cf("push", a.appName, "-p", "assets/stress-app", "-f", "assets/stress-app/manifest.yml", "--no-start"), 5*time.Minute).Should(gexec.Exit(0))
}

func (a *cfApp) Push() {
	// push dummy app
	Eventually(cf.Cf("push", a.appName, "-p", "assets/temp-app", "-f", "assets/temp-app/manifest.yml", "--no-start"), 5*time.Minute).Should(gexec.Exit(0))
	Eventually(cf.Cf("set-env", a.appName, "ENDPOINT_TO_HIT", fmt.Sprintf("http://%s.%s", a.appName, config.OverrideDomain)), 5*time.Minute).Should(gexec.Exit(0))
}

func (a *cfApp) CopyBitsTo(target *cfApp) {
	Eventually(cf.Cf("copy-source", a.appName, target.appName, "--no-restart"), 5*time.Minute).Should(gexec.Exit(0))
}

func (a *cfApp) Start() {
	Eventually(cf.Cf("start", a.appName), 5*time.Minute).Should(gexec.Exit(0))
	Eventually(cf.Cf("logs", a.appName, "--recent")).Should(gbytes.Say("[HEALTH/0]"))

	curlAppMain := func() string {
		response, err := a.Curl("")
		if err != nil {
			return ""
		}
		return response
	}

	Eventually(curlAppMain).Should(ContainSubstring("application_name"))
}

func (a *cfApp) Curl(endpoint string) (string, error) {
	endpointUrl := a.appRoute
	endpointUrl.Path = endpoint

	url := endpointUrl.String()

	statusCode, body, err := curl(url)
	if err != nil {
		return "", err
	}

	a.attemptedCurls++

	switch {
	case statusCode == 200:
		return string(body), nil

	case a.shouldRetryRequest(statusCode):
		fmt.Fprintln(GinkgoWriter, "RETRYING CURL", newCurlErr(url, statusCode, body).Error())
		a.failedCurls++
		time.Sleep(2 * time.Second)
		return a.Curl(endpoint)

	default:
		err := newCurlErr(url, statusCode, body)
		fmt.Fprintln(GinkgoWriter, "FAILED CURL", err.Error())
		a.failedCurls++
		return "", err
	}
}

func (a *cfApp) shouldRetryRequest(statusCode int) bool {
	if statusCode == 503 || statusCode == 404 {
		return a.failedCurls < a.maxFailedCurls
	}
	return false
}

func curl(url string) (statusCode int, body string, err error) {
	resp, err := http.Get(url)
	if err != nil {
		return 0, "", err
	}

	defer resp.Body.Close()

	bytes, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return 0, "", err
	}
	return resp.StatusCode, string(bytes), nil
}

func newCurlErr(url string, statusCode int, body string) error {
	return fmt.Errorf("Endpoint: %s, Status Code: %d, Body: %s", url, statusCode, body)
}
