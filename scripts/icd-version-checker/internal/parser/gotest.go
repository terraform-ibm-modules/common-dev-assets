package parser

import (
	"fmt"
	"os"
	"regexp"

	"github.com/terraform-ibm-modules/common-dev-assets/scripts/icd-version-checker/internal/types"
)

// GoTestParser extracts version information from Go test files
type GoTestParser struct{}

// NewGoTestParser creates a new Go test file parser
func NewGoTestParser() *GoTestParser {
	return &GoTestParser{}
}

// Parse extracts version info from a Go test file
func (p *GoTestParser) Parse(filePath string, variableName string) (*types.VersionInfo, error) {
	content, err := os.ReadFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to read %s: %w", filePath, err)
	}

	return p.ParseContent(string(content), variableName)
}

// ParseContent extracts version info from Go source content
// First tries to find const latestVersion, then falls back to "<variableName>": "<version>" pattern
func (p *GoTestParser) ParseContent(content string, variableName string) (*types.VersionInfo, error) {
	// First try: const latestVersion = "17"
	pattern := `const\s+latestVersion\s*=\s*"([0-9]+(?:\.[0-9]+)*)"`
	re := regexp.MustCompile(pattern)

	match := re.FindStringSubmatch(content)
	if match != nil && len(match) >= 2 {
		version := match[1]
		return &types.VersionInfo{
			Versions:      []string{version},
			LatestVersion: version,
		}, nil
	}

	// Fallback: look for "<variableName>": "<version>" pattern (e.g., "edb_version": "12")
	if variableName != "" {
		fallbackPattern := fmt.Sprintf(`"%s"\s*:\s*"([0-9]+(?:\.[0-9]+)*)"`, regexp.QuoteMeta(variableName))
		fallbackRe := regexp.MustCompile(fallbackPattern)

		fallbackMatch := fallbackRe.FindStringSubmatch(content)
		if fallbackMatch != nil && len(fallbackMatch) >= 2 {
			version := fallbackMatch[1]
			return &types.VersionInfo{
				Versions:      []string{version},
				LatestVersion: version,
			}, nil
		}
	}

	return nil, fmt.Errorf("latestVersion constant not found")
}
