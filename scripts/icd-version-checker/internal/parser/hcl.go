package parser

import (
	"fmt"
	"os"
	"regexp"
	"sort"
	"strings"

	"github.com/terraform-ibm-modules/common-dev-assets/scripts/icd-version-checker/internal/types"
)

// HCLParser extracts version information from Terraform variables.tf files
type HCLParser struct{}

// NewHCLParser creates a new HCL parser
func NewHCLParser() *HCLParser {
	return &HCLParser{}
}

// Parse extracts version information from a variables.tf file
// It looks for the validation block pattern:
//
//	var.{variable_name} == "version"
func (p *HCLParser) Parse(filePath string, variableName string) (*types.VersionInfo, error) {
	content, err := os.ReadFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to read %s: %w", filePath, err)
	}

	return p.ParseContent(string(content), variableName)
}

// ParseContent extracts version information from HCL content string
func (p *HCLParser) ParseContent(content string, variableName string) (*types.VersionInfo, error) {
	// Build regex pattern to match: var.{variable_name} == "version"
	// The version can be a number like "17" or a semver-like "8.0"
	pattern := fmt.Sprintf(`var\.%s\s*==\s*"([0-9]+(?:\.[0-9]+)*)"`, regexp.QuoteMeta(variableName))
	re := regexp.MustCompile(pattern)

	matches := re.FindAllStringSubmatch(content, -1)
	if len(matches) == 0 {
		return nil, fmt.Errorf("no versions found for variable %s", variableName)
	}

	// Extract unique versions
	versionSet := make(map[string]bool)
	for _, match := range matches {
		if len(match) > 1 {
			versionSet[match[1]] = true
		}
	}

	// Convert to slice and sort
	versions := make([]string, 0, len(versionSet))
	for v := range versionSet {
		versions = append(versions, v)
	}
	sortVersions(versions)

	// Latest version is the highest (last after sorting)
	latestVersion := ""
	if len(versions) > 0 {
		latestVersion = versions[len(versions)-1]
	}

	return &types.VersionInfo{
		Versions:      versions,
		LatestVersion: latestVersion,
	}, nil
}

// sortVersions sorts version strings in ascending order
// Handles both simple integers (13, 14, 15) and semver-like versions (8.0, 8.7)
func sortVersions(versions []string) {
	sort.Slice(versions, func(i, j int) bool {
		return compareVersions(versions[i], versions[j]) < 0
	})
}

// compareVersions compares two version strings
// Returns -1 if a < b, 0 if a == b, 1 if a > b
func compareVersions(a, b string) int {
	partsA := strings.Split(a, ".")
	partsB := strings.Split(b, ".")

	// Compare each part numerically
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
