package cmd

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"github.com/terraform-ibm-modules/common-dev-assets/scripts/icd-version-checker/internal/ibmcloud"
	"github.com/terraform-ibm-modules/common-dev-assets/scripts/icd-version-checker/internal/types"
)

// FetchResult represents the output of the fetch command
type FetchResult struct {
	ServiceType   string   `json:"service_type"`
	VariableName  string   `json:"variable_name"`
	Versions      []string `json:"versions"`
	LatestVersion string   `json:"latest_version"`
}

var fetchCmd = &cobra.Command{
	Use:   "fetch",
	Short: "Fetch available versions from IBM Cloud Databases API",
	Long: `Fetch queries the IBM Cloud Databases API to get the list of
available versions for the specified service type.

API key can be provided via:
  --ibmcloud-api-key flag
  IBMCLOUD_API_KEY environment variable
  TF_VAR_ibmcloud_api_key environment variable`,
	RunE: runFetch,
}

func init() {
	rootCmd.AddCommand(fetchCmd)
	fetchCmd.Flags().String("ibmcloud-api-key", "", "IBM Cloud API key (or set IBMCLOUD_API_KEY/TF_VAR_ibmcloud_api_key env var)")
}

func runFetch(cmd *cobra.Command, args []string) error {
	serviceType, _ := cmd.Flags().GetString("service-type")
	apiKey, _ := cmd.Flags().GetString("ibmcloud-api-key")

	if serviceType == "" {
		return fmt.Errorf("--service-type is required")
	}

	result, err := doFetch(serviceType, apiKey)
	if err != nil {
		return err
	}

	output, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal result: %w", err)
	}

	fmt.Println(string(output))
	return nil
}

// doFetch is the internal implementation that can be reused by sync
func doFetch(serviceType, apiKey string) (*FetchResult, error) {
	// Get API key from flag or environment
	if apiKey == "" {
		apiKey = os.Getenv("IBMCLOUD_API_KEY")
	}
	if apiKey == "" {
		apiKey = os.Getenv("TF_VAR_ibmcloud_api_key")
	}
	if apiKey == "" {
		return nil, fmt.Errorf("IBM Cloud API key required: use --ibmcloud-api-key or set IBMCLOUD_API_KEY/TF_VAR_ibmcloud_api_key env var")
	}

	config := types.GetServiceConfig(serviceType)

	client := ibmcloud.NewClient(apiKey)
	versions, latest, err := client.GetDeployableVersions(serviceType)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch API versions: %w", err)
	}

	return &FetchResult{
		ServiceType:   serviceType,
		VariableName:  config.VariableName,
		Versions:      versions,
		LatestVersion: latest,
	}, nil
}
