package cedar_test

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("Seeding", func() {
	It("Successfully seeds the apps", func() {
		By("Precompiling a binary for the test app")
		os.Setenv("GOOS", "linux")
		os.Setenv("GOARCH", "amd64")
		os.Chdir("assets/stress-app")
		buildCmd := exec.Command("go", "build", ".")
		err := buildCmd.Run()
		Expect(err).NotTo(HaveOccurred())
		os.Chdir("../..")

		By("Pushing the binary as app bits to a designated seed app")
		masterApp := newCfApp("light-master", 5)
		masterApp.PushMaster()

		By("Push N empty, unstarted apps configured to use the binary buildpack")
		numCopies, err := strconv.Atoi(os.Getenv("N"))
		Expect(err).NotTo(HaveOccurred())
		var tempApps []*cfApp
		for i := 0; i < numCopies; i++ {
			tempApp := newCfApp(fmt.Sprintf("light-copy-%d", i), 5)
			tempApp.Push()
			tempApps = append(tempApps, tempApp)
		}

		By("Copying the seed bits to the N target apps")
		for i := 0; i < numCopies; i++ {
			masterApp.CopyBitsTo(tempApps[i])
		}

		By("Starting the N apps and verifying the copied app is running and routable")
		for i := 0; i < numCopies; i++ {
			tempApps[i].Start()
		}
	})
})
