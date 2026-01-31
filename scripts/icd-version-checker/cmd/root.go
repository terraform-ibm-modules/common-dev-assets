package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "icd-version-checker",
	Short: "A tool to extract and update ICD version information in Terraform modules",
	Long: `icd-version-checker is a CLI tool that parses and updates version information
in IBM Cloud Databases (ICD) Terraform modules.

It can extract current versions from:
  - variables.tf (validation blocks)
  - ibm_catalog.json (version options)
  - tests/pr_test.go (latestVersion constant)

And update these files with new versions from the IBM Cloud API.`,
}

// Execute adds all child commands to the root command and sets flags appropriately.
func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func init() {
	rootCmd.PersistentFlags().StringP("service-type", "s", "", "ICD service type (e.g., postgresql, mysql, redis)")
	rootCmd.PersistentFlags().StringP("repo-root", "r", ".", "Path to the repository root")
}
