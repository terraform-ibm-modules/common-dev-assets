package main

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/terraform-ibm-modules/common-dev-assets/scripts/icd-version-checker/internal/parser"
	"github.com/terraform-ibm-modules/common-dev-assets/scripts/icd-version-checker/internal/types"
	"github.com/terraform-ibm-modules/common-dev-assets/scripts/icd-version-checker/internal/updater"
)

func TestIntegration_ExtractFromTestdata(t *testing.T) {
	testdataDir := filepath.Join("testdata", "postgresql")

	t.Run("extract from variables.tf", func(t *testing.T) {
		hclParser := parser.NewHCLParser()
		info, err := hclParser.Parse(filepath.Join(testdataDir, "variables.tf"), "postgresql_version")
		require.NoError(t, err)

		assert.Equal(t, []string{"13", "14", "15", "16", "17"}, info.Versions)
		assert.Equal(t, "17", info.LatestVersion)
	})

	t.Run("extract from ibm_catalog.json", func(t *testing.T) {
		catalogParser := parser.NewCatalogParser()
		info, err := catalogParser.Parse(filepath.Join(testdataDir, "ibm_catalog.json"), "postgresql_version")
		require.NoError(t, err)

		assert.Equal(t, []string{"13", "14", "15", "16", "17"}, info.Versions)
		assert.Equal(t, "17", info.LatestVersion)
	})

	t.Run("extract from tests/pr_test.go", func(t *testing.T) {
		goParser := parser.NewGoTestParser()
		info, err := goParser.Parse(filepath.Join(testdataDir, "tests", "pr_test.go"), "postgresql_version")
		require.NoError(t, err)

		assert.Equal(t, "17", info.LatestVersion)
	})
}

func TestIntegration_UpdateCycle(t *testing.T) {
	// Create temp directory with copies of test files
	tempDir, err := os.MkdirTemp("", "icd-version-checker-test")
	require.NoError(t, err)
	defer os.RemoveAll(tempDir)

	// Copy test files to temp dir
	testdataDir := filepath.Join("testdata", "postgresql")
	copyFile(t, filepath.Join(testdataDir, "variables.tf"), filepath.Join(tempDir, "variables.tf"))
	copyFile(t, filepath.Join(testdataDir, "ibm_catalog.json"), filepath.Join(tempDir, "ibm_catalog.json"))

	testsDir := filepath.Join(tempDir, "tests")
	require.NoError(t, os.MkdirAll(testsDir, 0755))
	copyFile(t, filepath.Join(testdataDir, "tests", "pr_test.go"), filepath.Join(testsDir, "pr_test.go"))

	// Define update request - add version 18
	req := &types.UpdateRequest{
		ServiceType:   "postgresql",
		VariableName:  "postgresql_version",
		NewVersions:   []string{"14", "15", "16", "17", "18"},
		LatestVersion: "18",
		RepoRoot:      tempDir,
	}

	// Update files
	t.Run("update variables.tf", func(t *testing.T) {
		hclUpdater := updater.NewHCLUpdater()
		err := hclUpdater.Update(filepath.Join(tempDir, "variables.tf"), req)
		require.NoError(t, err)

		// Verify update
		hclParser := parser.NewHCLParser()
		info, err := hclParser.Parse(filepath.Join(tempDir, "variables.tf"), "postgresql_version")
		require.NoError(t, err)

		assert.Equal(t, []string{"14", "15", "16", "17", "18"}, info.Versions)
		assert.Equal(t, "18", info.LatestVersion)
	})

	t.Run("update ibm_catalog.json", func(t *testing.T) {
		catalogUpdater := updater.NewCatalogUpdater()
		err := catalogUpdater.Update(filepath.Join(tempDir, "ibm_catalog.json"), req)
		require.NoError(t, err)

		// Verify update
		catalogParser := parser.NewCatalogParser()
		info, err := catalogParser.Parse(filepath.Join(tempDir, "ibm_catalog.json"), "postgresql_version")
		require.NoError(t, err)

		assert.Equal(t, []string{"14", "15", "16", "17", "18"}, info.Versions)
		assert.Equal(t, "18", info.LatestVersion)
	})

	t.Run("update tests/pr_test.go", func(t *testing.T) {
		goUpdater := updater.NewGoTestUpdater()
		err := goUpdater.Update(filepath.Join(testsDir, "pr_test.go"), req)
		require.NoError(t, err)

		// Verify update
		goParser := parser.NewGoTestParser()
		info, err := goParser.Parse(filepath.Join(testsDir, "pr_test.go"), "postgresql_version")
		require.NoError(t, err)

		assert.Equal(t, "18", info.LatestVersion)
	})
}

func copyFile(t *testing.T, src, dst string) {
	content, err := os.ReadFile(src)
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(dst, content, 0644))
}
