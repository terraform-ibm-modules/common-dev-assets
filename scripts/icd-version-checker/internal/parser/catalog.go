package parser

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/terraform-ibm-modules/common-dev-assets/scripts/icd-version-checker/internal/types"
)

// CatalogFile represents the structure of ibm_catalog.json
type CatalogFile struct {
	Products []Product `json:"products"`
}

// Product represents a product in the catalog
type Product struct {
	Flavors []Flavor `json:"flavors"`
}

// Flavor represents a flavor configuration
type Flavor struct {
	Name          string       `json:"name"`
	Configuration []ConfigItem `json:"configuration"`
}

// ConfigItem represents a configuration item
type ConfigItem struct {
	Key          string       `json:"key"`
	DefaultValue interface{}  `json:"default_value,omitempty"`
	Options      []OptionItem `json:"options,omitempty"`
}

// OptionItem represents an option in a configuration item
type OptionItem struct {
	DisplayName string `json:"displayname"`
	Value       string `json:"value"`
}

// CatalogParser extracts version information from ibm_catalog.json files
type CatalogParser struct{}

// NewCatalogParser creates a new catalog parser
func NewCatalogParser() *CatalogParser {
	return &CatalogParser{}
}

// Parse extracts version information from an ibm_catalog.json file
func (p *CatalogParser) Parse(filePath string, variableName string) (*types.VersionInfo, error) {
	content, err := os.ReadFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to read %s: %w", filePath, err)
	}

	return p.ParseContent(content, variableName)
}

// ParseContent extracts version information from catalog JSON content
func (p *CatalogParser) ParseContent(content []byte, variableName string) (*types.VersionInfo, error) {
	var catalog CatalogFile
	if err := json.Unmarshal(content, &catalog); err != nil {
		return nil, fmt.Errorf("failed to parse catalog JSON: %w", err)
	}

	// Find version configuration across all products and flavors
	var versions []string
	var defaultValue string
	found := false

	for _, product := range catalog.Products {
		for _, flavor := range product.Flavors {
			for _, config := range flavor.Configuration {
				if config.Key == variableName {
					found = true

					// Extract versions from options
					for _, opt := range config.Options {
						versions = append(versions, opt.Value)
					}

					// Get default value (could be string or other type)
					if config.DefaultValue != nil {
						switch v := config.DefaultValue.(type) {
						case string:
							defaultValue = v
						case float64:
							defaultValue = fmt.Sprintf("%v", v)
						}
					}

					// Only need to find it once (all flavors should have same versions)
					break
				}
			}
			if found {
				break
			}
		}
		if found {
			break
		}
	}

	if !found {
		return nil, fmt.Errorf("configuration key %s not found in catalog", variableName)
	}

	// If no options array, fall back to default_value (single-version services like Redis)
	if len(versions) == 0 {
		if defaultValue != "" {
			versions = []string{defaultValue}
		} else {
			return nil, fmt.Errorf("no version options found for %s", variableName)
		}
	}

	// Remove duplicates and sort
	versionSet := make(map[string]bool)
	for _, v := range versions {
		versionSet[v] = true
	}
	versions = make([]string, 0, len(versionSet))
	for v := range versionSet {
		versions = append(versions, v)
	}
	sortVersions(versions)

	// Latest version is always the highest version (not default_value, which may be older stable)
	latestVersion := ""
	if len(versions) > 0 {
		latestVersion = versions[len(versions)-1]
	}
	_ = defaultValue // default_value is IBM's recommended default, not necessarily the latest

	return &types.VersionInfo{
		Versions:      versions,
		LatestVersion: latestVersion,
	}, nil
}
