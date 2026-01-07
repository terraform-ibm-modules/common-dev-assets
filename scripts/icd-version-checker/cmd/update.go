package cmd

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/spf13/cobra"
	"github.com/terraform-ibm-modules/common-dev-assets/scripts/icd-version-checker/internal/types"
	"github.com/terraform-ibm-modules/common-dev-assets/scripts/icd-version-checker/internal/updater"
)

var updateCmd = &cobra.Command{
	Use:   "update",
	Short: "Update version information in repository files",
	Long: `Update version information in:
  - variables.tf (validation block)
  - ibm_catalog.json (version options)
  - tests/pr_test.go (latestVersion constant)

Output is JSON listing which files were updated.`,
	RunE: runUpdate,
}

func init() {
	rootCmd.AddCommand(updateCmd)
	updateCmd.Flags().StringP("versions", "v", "", "Comma-separated list of versions (e.g., '15,16,17,18')")
	updateCmd.Flags().StringP("latest", "l", "", "Latest/default version (optional - defaults to last version in sorted list)")
	updateCmd.Flags().Bool("dry-run", false, "Show what would be updated without making changes")
}

func runUpdate(cmd *cobra.Command, args []string) error {
	serviceType, _ := cmd.Flags().GetString("service-type")
	repoRoot, _ := cmd.Flags().GetString("repo-root")
	versionsStr, _ := cmd.Flags().GetString("versions")
	latestVersion, _ := cmd.Flags().GetString("latest")
	dryRun, _ := cmd.Flags().GetBool("dry-run")

	if serviceType == "" {
		return fmt.Errorf("--service-type is required")
	}
	if versionsStr == "" {
		return fmt.Errorf("--versions is required")
	}

	// Parse versions
	versions := strings.Split(versionsStr, ",")
	for i := range versions {
		versions[i] = strings.TrimSpace(versions[i])
	}

	// If latest not provided, derive it from versions (sort and take last)
	if latestVersion == "" {
		if len(versions) == 0 {
			return fmt.Errorf("versions list is empty")
		}
		latestVersion = getLatestVersion(versions)
	}

	// Get service configuration
	config := types.GetServiceConfig(serviceType)

	req := &types.UpdateRequest{
		ServiceType:   serviceType,
		VariableName:  config.VariableName,
		NewVersions:   versions,
		LatestVersion: latestVersion,
		RepoRoot:      repoRoot,
	}

	if dryRun {
		fmt.Fprintf(os.Stderr, "DRY RUN: Would update files with versions %v (latest: %s)\n", versions, latestVersion)
	}

	result := doUpdate(req, repoRoot, dryRun)

	// Output JSON
	output, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal result: %w", err)
	}

	fmt.Println(string(output))

	// Return error if any updates failed
	if len(result.Errors) > 0 {
		return fmt.Errorf("some updates failed")
	}

	return nil
}

// doUpdate is the internal implementation that can be reused by sync
func doUpdate(req *types.UpdateRequest, repoRoot string, dryRun bool) *types.UpdateResult {
	result := &types.UpdateResult{
		UpdatedFiles: []string{},
		Errors:       []string{},
	}

	// Update variables.tf
	variablesPath := filepath.Join(repoRoot, "variables.tf")
	if !dryRun {
		hclUpdater := updater.NewHCLUpdater()
		if err := hclUpdater.Update(variablesPath, req); err != nil {
			result.Errors = append(result.Errors, fmt.Sprintf("variables.tf: %v", err))
		} else {
			result.UpdatedFiles = append(result.UpdatedFiles, "variables.tf")
		}
	} else {
		result.UpdatedFiles = append(result.UpdatedFiles, "variables.tf")
	}

	// Update ibm_catalog.json (if it exists)
	catalogPath := filepath.Join(repoRoot, "ibm_catalog.json")
	if _, err := os.Stat(catalogPath); err == nil {
		if !dryRun {
			catalogUpdater := updater.NewCatalogUpdater()
			if err := catalogUpdater.Update(catalogPath, req); err != nil {
				result.Errors = append(result.Errors, fmt.Sprintf("ibm_catalog.json: %v", err))
			} else {
				result.UpdatedFiles = append(result.UpdatedFiles, "ibm_catalog.json")
			}
		} else {
			result.UpdatedFiles = append(result.UpdatedFiles, "ibm_catalog.json")
		}
	}

	// Update tests/pr_test.go (if it exists)
	testPath := filepath.Join(repoRoot, "tests", "pr_test.go")
	if _, err := os.Stat(testPath); err == nil {
		if !dryRun {
			goUpdater := updater.NewGoTestUpdater()
			if err := goUpdater.Update(testPath, req); err != nil {
				// latestVersion constant might not exist in all test files
				if !strings.Contains(err.Error(), "not found") {
					result.Errors = append(result.Errors, fmt.Sprintf("tests/pr_test.go: %v", err))
				}
			} else {
				result.UpdatedFiles = append(result.UpdatedFiles, "tests/pr_test.go")
			}
		} else {
			result.UpdatedFiles = append(result.UpdatedFiles, "tests/pr_test.go")
		}
	}

	return result
}

// getLatestVersion returns the highest version from the list
func getLatestVersion(versions []string) string {
	if len(versions) == 0 {
		return ""
	}
	if len(versions) == 1 {
		return versions[0]
	}

	// Make a copy to avoid modifying the original
	sorted := make([]string, len(versions))
	copy(sorted, versions)

	// Sort versions in ascending order
	sort.Slice(sorted, func(i, j int) bool {
		return compareVersions(sorted[i], sorted[j]) < 0
	})

	return sorted[len(sorted)-1]
}

// compareVersions compares two version strings
// Returns -1 if a < b, 0 if a == b, 1 if a > b
func compareVersions(a, b string) int {
	partsA := strings.Split(a, ".")
	partsB := strings.Split(b, ".")

	maxLen := len(partsA)
	if len(partsB) > maxLen {
		maxLen = len(partsB)
	}

	for i := 0; i < maxLen; i++ {
		var numA, numB int
		if i < len(partsA) {
			fmt.Sscanf(partsA[i], "%d", &numA)
		}
		if i < len(partsB) {
			fmt.Sscanf(partsB[i], "%d", &numB)
		}

		if numA < numB {
			return -1
		}
		if numA > numB {
			return 1
		}
	}
	return 0
}
