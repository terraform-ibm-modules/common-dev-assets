// Tests in this file are NOT run in the PR pipeline. They are run in the continuous testing pipeline along with the ones in pr_test.go
package test

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

const nonDefaultExampleTerraformDir = "examples/non-default"

func TestRunNonDefaultExample(t *testing.T) {
	t.Parallel()

	options := setupOptions(t, "non-default-tmp", nonDefaultExampleTerraformDir)

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored")
	assert.NotNil(t, output, "Expected some output")
}
