package updater

import (
	"fmt"
	"os"
	"regexp"
	"strings"

	"github.com/terraform-ibm-modules/common-dev-assets/scripts/icd-version-checker/internal/types"
)

// CatalogUpdater updates version information in ibm_catalog.json files
type CatalogUpdater struct{}

// NewCatalogUpdater creates a new catalog updater
func NewCatalogUpdater() *CatalogUpdater {
	return &CatalogUpdater{}
}

// Update modifies the ibm_catalog.json file with new versions
func (u *CatalogUpdater) Update(filePath string, req *types.UpdateRequest) error {
	content, err := os.ReadFile(filePath)
	if err != nil {
		return fmt.Errorf("failed to read %s: %w", filePath, err)
	}

	updatedContent, err := u.UpdateContent(content, req)
	if err != nil {
		return err
	}

	if err := os.WriteFile(filePath, updatedContent, 0644); err != nil {
		return fmt.Errorf("failed to write %s: %w", filePath, err)
	}

	return nil
}

// UpdateContent updates version configuration in catalog JSON content
// Uses surgical line-based replacement to preserve formatting and field ordering
func (u *CatalogUpdater) UpdateContent(content []byte, req *types.UpdateRequest) ([]byte, error) {
	text := string(content)

	// Sort versions ascending for display order (13, 14, 15, 16, 17)
	versions := make([]string, len(req.NewVersions))
	copy(versions, req.NewVersions)
	sortVersionsAsc(versions)

	// Check if the variable exists in the catalog
	keyPattern := fmt.Sprintf(`"key"\s*:\s*"%s"`, regexp.QuoteMeta(req.VariableName))
	if !regexp.MustCompile(keyPattern).MatchString(text) {
		return nil, fmt.Errorf("configuration key %s not found in catalog", req.VariableName)
	}

	// Process line by line to update default_value and options
	text = updateCatalogLines(text, req.VariableName, req.LatestVersion, versions)

	return []byte(text), nil
}

// updateCatalogLines processes the catalog line by line to update default_value and options
func updateCatalogLines(text, variableName, newDefaultValue string, versions []string) string {
	lines := strings.Split(text, "\n")
	var result []string

	inTargetConfig := false
	bracketCount := 0
	skipUntilOptionsEnd := false
	configBraceDepth := 0

	// Pattern to match the key line
	keyLinePattern := regexp.MustCompile(`"key"\s*:\s*"` + regexp.QuoteMeta(variableName) + `"`)
	// Pattern to match default_value line
	defaultValuePattern := regexp.MustCompile(`^(\s*)"default_value"\s*:\s*"[^"]*"(.*)$`)
	// Pattern to detect start of options
	optionsStartPattern := regexp.MustCompile(`^(\s*)"options"\s*:\s*\[`)

	for _, line := range lines {
		// Track if we're in the target config block
		if keyLinePattern.MatchString(line) {
			inTargetConfig = true
			configBraceDepth = 0
		}

		// Track brace depth to know when we exit the config block
		if inTargetConfig {
			configBraceDepth += strings.Count(line, "{") - strings.Count(line, "}")
			// If we see another "key": line, we've moved to next config
			if strings.Contains(line, `"key"`) && !keyLinePattern.MatchString(line) {
				inTargetConfig = false
			}
		}

		// Skip lines while we're removing the old options array
		if skipUntilOptionsEnd {
			bracketCount += strings.Count(line, "[") - strings.Count(line, "]")
			if bracketCount <= 0 {
				skipUntilOptionsEnd = false
			}
			continue
		}

		// If in target config, check for default_value to update
		if inTargetConfig {
			if match := defaultValuePattern.FindStringSubmatch(line); match != nil {
				indent := match[1]
				trailing := match[2]
				result = append(result, fmt.Sprintf(`%s"default_value": "%s"%s`, indent, newDefaultValue, trailing))
				continue
			}

			// Check for options array to replace
			if match := optionsStartPattern.FindStringSubmatch(line); match != nil {
				indent := match[1]
				// Build new options with detected indentation
				newOptionsStr := buildOptionsArray(versions, indent)
				result = append(result, indent+`"options": `+newOptionsStr)

				// Start skipping old options content
				skipUntilOptionsEnd = true
				bracketCount = strings.Count(line, "[") - strings.Count(line, "]")
				if bracketCount <= 0 {
					skipUntilOptionsEnd = false
				}
				continue
			}
		}

		result = append(result, line)
	}

	return strings.Join(result, "\n")
}

// buildOptionsArray creates a formatted options array string
func buildOptionsArray(versions []string, baseIndent string) string {
	if len(versions) == 0 {
		return "[]"
	}

	innerIndent := baseIndent + "  "
	var optionLines []string
	for _, v := range versions {
		optionLines = append(optionLines, fmt.Sprintf(`%s{
%s  "displayname": "%s",
%s  "value": "%s"
%s}`, innerIndent, innerIndent, v, innerIndent, v, innerIndent))
	}

	return "[\n" + strings.Join(optionLines, ",\n") + "\n" + baseIndent + "]"
}
