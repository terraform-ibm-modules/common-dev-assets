package cmd

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"
	"github.com/terraform-ibm-modules/common-dev-assets/scripts/icd-version-checker/internal/parser"
	"github.com/terraform-ibm-modules/common-dev-assets/scripts/icd-version-checker/internal/types"
)

var extractCmd = &cobra.Command{
	Use:   "extract",
	Short: "Extract current version information from repository files",
	Long: `Extract version information from:
  - variables.tf (validation block)
  - ibm_catalog.json (version options)
  - tests/pr_test.go (latestVersion constant)

Output is JSON for easy integration with CI/CD workflows.`,
	RunE: runExtract,
}

func init() {
	rootCmd.AddCommand(extractCmd)
}

func runExtract(cmd *cobra.Command, args []string) error {
	serviceType, _ := cmd.Flags().GetString("service-type")
	repoRoot, _ := cmd.Flags().GetString("repo-root")

	if serviceType == "" {
		return fmt.Errorf("--service-type is required")
	}

	result := doExtract(serviceType, repoRoot)

	// Output JSON
	output, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal result: %w", err)
	}

	fmt.Println(string(output))
	return nil
}

// doExtract is the internal implementation that can be reused by sync
func doExtract(serviceType, repoRoot string) *types.ExtractResult {
	config := types.GetServiceConfig(serviceType)

	result := &types.ExtractResult{
		ServiceType:  serviceType,
		VariableName: config.VariableName,
	}

	// Parse variables.tf (required)
	variablesPath := filepath.Join(repoRoot, "variables.tf")
	hclParser := parser.NewHCLParser()
	if info, err := hclParser.Parse(variablesPath, config.VariableName); err != nil {
		result.Errors = append(result.Errors, fmt.Sprintf("variables.tf: %v", err))
	} else {
		result.VariablesTF = info
	}

	// Parse ibm_catalog.json (optional)
	catalogPath := filepath.Join(repoRoot, "ibm_catalog.json")
	if _, err := os.Stat(catalogPath); os.IsNotExist(err) {
		result.Skipped = append(result.Skipped, "ibm_catalog.json (file not found)")
	} else {
		catalogParser := parser.NewCatalogParser()
		if info, err := catalogParser.Parse(catalogPath, config.VariableName); err != nil {
			result.Errors = append(result.Errors, fmt.Sprintf("ibm_catalog.json: %v", err))
		} else {
			result.IBMCatalog = info
		}
	}

	// Parse tests/pr_test.go (optional)
	testPath := filepath.Join(repoRoot, "tests", "pr_test.go")
	if _, err := os.Stat(testPath); os.IsNotExist(err) {
		result.Skipped = append(result.Skipped, "tests/pr_test.go (file not found)")
	} else {
		goParser := parser.NewGoTestParser()
		if info, err := goParser.Parse(testPath, config.VariableName); err != nil {
			result.Errors = append(result.Errors, fmt.Sprintf("tests/pr_test.go: %v", err))
		} else {
			result.TestFile = info
		}
	}

	return result
}
