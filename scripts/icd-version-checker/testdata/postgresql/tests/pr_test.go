// Tests in this file are run in the PR pipeline
package test

import (
	"testing"
)

const fscloudExampleTerraformDir = "examples/fscloud"
const fullyConfigurableSolutionTerraformDir = "solutions/fully-configurable"
const securityEnforcedSolutionTerraformDir = "solutions/security-enforced"
const latestVersion = "17"

// Use existing resource group
const resourceGroup = "geretain-test-postgres"

func TestMain(m *testing.M) {
	// Test setup would go here
}

func TestExample(t *testing.T) {
	// Example test
}
