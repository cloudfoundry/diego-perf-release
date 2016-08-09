package cedar_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

var config *TestConfig

type TestConfig struct {
	OverrideDomain   string `json:"override_domain"`
	MaxPollingErrors int    `json:"max_polling_errors,omitempty"`
}

func TestCedar(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Cedar Suite")
}

var _ = BeforeSuite(func() {
	config = &TestConfig{
		OverrideDomain:   "bosh-lite.com",
		MaxPollingErrors: 1,
	}
})
