package cmd

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"github.com/terraform-ibm-modules/common-dev-assets/scripts/icd-version-checker/internal/types"
)

// SyncResult represents the output of the sync command
type SyncResult struct {
	ServiceType        string   `json:"service_type"`
	CurrentVersions    []string `json:"current_versions"`
	APIVersions        []string `json:"api_versions"`
	NewVersions        []string `json:"new_versions,omitempty"`
	DeprecatedVersions []string `json:"deprecated_versions,omitempty"`
	HasChanges         bool     `json:"has_changes"`
	UpdatedFiles       []string `json:"updated_files,omitempty"`
	DryRun             bool     `json:"dry_run"`
}

var syncCmd = &cobra.Command{
	Use:   "sync",
	Short: "Sync versions from IBM Cloud API (fetch + extract + compare + update)",
	Long: `Sync automatically:
  1. Fetches available versions from IBM Cloud Databases API (fetch)
  2. Extracts current versions from repository files (extract)
  3. Compares and detects changes
  4. Updates files if new versions are available (update)

This is a convenience command that combines fetch + extract + update.

API key can be provided via:
  --ibmcloud-api-key flag
  IBMCLOUD_API_KEY environment variable
  TF_VAR_ibmcloud_api_key environment variable (fallback)`,
	RunE: runSync,
}

func init() {
	rootCmd.AddCommand(syncCmd)
	syncCmd.Flags().String("ibmcloud-api-key", "", "IBM Cloud API key (or set IBMCLOUD_API_KEY/TF_VAR_ibmcloud_api_key env var)")
	syncCmd.Flags().Bool("dry-run", false, "Show what would change without modifying files")
}

func runSync(cmd *cobra.Command, args []string) error {
	serviceType, _ := cmd.Flags().GetString("service-type")
	repoRoot, _ := cmd.Flags().GetString("repo-root")
	apiKey, _ := cmd.Flags().GetString("ibmcloud-api-key")
	dryRun, _ := cmd.Flags().GetBool("dry-run")

	if serviceType == "" {
		return fmt.Errorf("--service-type is required")
	}

	result := &SyncResult{
		ServiceType: serviceType,
		DryRun:      dryRun,
	}

	// Step 1: Fetch versions from IBM Cloud API (reusing doFetch)
	fmt.Fprintf(os.Stderr, "Fetching versions from IBM Cloud API...\n")
	fetchResult, err := doFetch(serviceType, apiKey)
	if err != nil {
		return fmt.Errorf("failed to fetch API versions: %w", err)
	}
	result.APIVersions = fetchResult.Versions
	fmt.Fprintf(os.Stderr, "API versions: %v\n", fetchResult.Versions)

	// Step 2: Extract current versions from repo (reusing doExtract)
	fmt.Fprintf(os.Stderr, "Extracting current versions from repository...\n")
	extractResult := doExtract(serviceType, repoRoot)
	if extractResult.VariablesTF == nil {
		return fmt.Errorf("failed to extract current versions from variables.tf")
	}
	result.CurrentVersions = extractResult.VariablesTF.Versions
	fmt.Fprintf(os.Stderr, "Current versions: %v\n", extractResult.VariablesTF.Versions)

	// Step 3: Compare versions
	newVersions, deprecatedVersions := compareVersionSets(result.CurrentVersions, result.APIVersions)
	result.NewVersions = newVersions
	result.DeprecatedVersions = deprecatedVersions
	result.HasChanges = len(newVersions) > 0 || len(deprecatedVersions) > 0

	if !result.HasChanges {
		fmt.Fprintf(os.Stderr, "No changes detected - versions are up to date\n")
		outputJSON(result)
		return nil
	}

	fmt.Fprintf(os.Stderr, "Changes detected:\n")
	if len(newVersions) > 0 {
		fmt.Fprintf(os.Stderr, "  New versions: %v\n", newVersions)
	}
	if len(deprecatedVersions) > 0 {
		fmt.Fprintf(os.Stderr, "  Deprecated versions: %v\n", deprecatedVersions)
	}

	// Step 4: Update files (reusing doUpdate)
	fmt.Fprintf(os.Stderr, "Updating files...\n")
	req := &types.UpdateRequest{
		ServiceType:   serviceType,
		VariableName:  fetchResult.VariableName,
		NewVersions:   result.APIVersions,
		LatestVersion: fetchResult.LatestVersion, // Still needed for test file updates
		RepoRoot:      repoRoot,
	}

	updateResult := doUpdate(req, repoRoot, dryRun)
	result.UpdatedFiles = updateResult.UpdatedFiles

	if dryRun {
		fmt.Fprintf(os.Stderr, "DRY RUN: Would update files\n")
	} else {
		fmt.Fprintf(os.Stderr, "Updated files: %v\n", result.UpdatedFiles)
	}

	outputJSON(result)
	return nil
}

// compareVersionSets returns new and deprecated versions
func compareVersionSets(current, api []string) (newVersions, deprecated []string) {
	currentSet := make(map[string]bool)
	for _, v := range current {
		currentSet[v] = true
	}

	apiSet := make(map[string]bool)
	for _, v := range api {
		apiSet[v] = true
	}

	// New versions: in API but not in current
	for _, v := range api {
		if !currentSet[v] {
			newVersions = append(newVersions, v)
		}
	}

	// Deprecated versions: in current but not in API
	for _, v := range current {
		if !apiSet[v] {
			deprecated = append(deprecated, v)
		}
	}

	return
}

func outputJSON(v interface{}) {
	output, _ := json.MarshalIndent(v, "", "  ")
	fmt.Println(string(output))
}
