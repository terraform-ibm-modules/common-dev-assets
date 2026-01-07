package updater

import (
	"fmt"
	"os"
	"regexp"
	"sort"
	"strings"

	"github.com/terraform-ibm-modules/common-dev-assets/scripts/icd-version-checker/internal/types"
)

// HCLUpdater updates version information in Terraform variables.tf files
type HCLUpdater struct{}

// NewHCLUpdater creates a new HCL updater
func NewHCLUpdater() *HCLUpdater {
	return &HCLUpdater{}
}

// Update modifies the variables.tf file with new versions
func (u *HCLUpdater) Update(filePath string, req *types.UpdateRequest) error {
	content, err := os.ReadFile(filePath)
	if err != nil {
		return fmt.Errorf("failed to read %s: %w", filePath, err)
	}

	updatedContent, err := u.UpdateContent(string(content), req)
	if err != nil {
		return err
	}

	if err := os.WriteFile(filePath, []byte(updatedContent), 0644); err != nil {
		return fmt.Errorf("failed to write %s: %w", filePath, err)
	}

	return nil
}

// UpdateContent updates the version validation in HCL content
func (u *HCLUpdater) UpdateContent(content string, req *types.UpdateRequest) (string, error) {
	// Sort versions in descending order (newest first) to match existing style
	versions := make([]string, len(req.NewVersions))
	copy(versions, req.NewVersions)
	sortVersionsDesc(versions)

	// Build the new condition lines
	conditionLines := []string{
		fmt.Sprintf("      var.%s == null,", req.VariableName),
	}
	for _, v := range versions {
		conditionLines = append(conditionLines, fmt.Sprintf("      var.%s == \"%s\",", req.VariableName, v))
	}
	// Remove trailing comma from last line
	lastIdx := len(conditionLines) - 1
	conditionLines[lastIdx] = strings.TrimSuffix(conditionLines[lastIdx], ",")

	newCondition := strings.Join(conditionLines, "\n")

	// Build regex to match the condition block
	// Pattern: condition = anytrue([ ... ])
	conditionPattern := fmt.Sprintf(
		`(condition\s*=\s*anytrue\(\[)\s*\n(\s*var\.%s\s*==\s*(?:null|"[^"]*"),?\s*\n)+(\s*\]\))`,
		regexp.QuoteMeta(req.VariableName),
	)
	conditionRe := regexp.MustCompile(conditionPattern)

	if !conditionRe.MatchString(content) {
		return "", fmt.Errorf("could not find validation condition for %s", req.VariableName)
	}

	// Replace the condition block
	content = conditionRe.ReplaceAllString(content, fmt.Sprintf("${1}\n%s\n${3}", newCondition))

	// Update error_message ONLY in the version variable's validation block
	// Build the version list string: "13, 14, 15, 16 or 17"
	versionsAsc := make([]string, len(req.NewVersions))
	copy(versionsAsc, req.NewVersions)
	sortVersionsAsc(versionsAsc)
	versionListStr := formatVersionList(versionsAsc)
	newErrorMsg := fmt.Sprintf("Version must be %s. If no value passed, the current ICD preferred version is used.", versionListStr)

	// Find the variable block and only replace error_message within it
	content = updateErrorMessageInVersionVariable(content, req.VariableName, newErrorMsg)

	return content, nil
}

// updateErrorMessageInVersionVariable updates only the error_message in the version variable's validation block
func updateErrorMessageInVersionVariable(content, variableName, newErrorMsg string) string {
	lines := strings.Split(content, "\n")
	var result []string

	// Track if we're inside the target variable block
	inTargetVariable := false
	inValidationBlock := false
	braceDepth := 0

	// Pattern to detect variable declaration
	varPattern := regexp.MustCompile(`^\s*variable\s+"` + regexp.QuoteMeta(variableName) + `"\s*\{`)
	// Pattern to detect validation block
	validationPattern := regexp.MustCompile(`^\s*validation\s*\{`)
	// Pattern to match error_message
	errorMsgPattern := regexp.MustCompile(`^(\s*error_message\s*=\s*)"[^"]*"(.*)$`)

	for _, line := range lines {
		// Check if we're entering the target variable
		if varPattern.MatchString(line) {
			inTargetVariable = true
			braceDepth = 1
		} else if inTargetVariable {
			// Track brace depth to know when we exit the variable block
			braceDepth += strings.Count(line, "{") - strings.Count(line, "}")

			// Check if we're entering a validation block
			if validationPattern.MatchString(line) {
				inValidationBlock = true
			}

			// Check if we're exiting the variable block
			if braceDepth <= 0 {
				inTargetVariable = false
				inValidationBlock = false
			}

			// Replace error_message only if we're in the target variable's validation block
			// and this is the first validation block (which contains the version check)
			if inTargetVariable && inValidationBlock {
				if match := errorMsgPattern.FindStringSubmatch(line); match != nil {
					line = match[1] + `"` + newErrorMsg + `"` + match[2]
					// Only replace the first error_message in the validation block
					inValidationBlock = false
				}
			}
		}

		result = append(result, line)
	}

	return strings.Join(result, "\n")
}

// formatVersionList formats versions as "13, 14, 15, 16 or 17"
func formatVersionList(versions []string) string {
	if len(versions) == 0 {
		return ""
	}
	if len(versions) == 1 {
		return versions[0]
	}
	if len(versions) == 2 {
		return versions[0] + " or " + versions[1]
	}

	// Join all but last with ", " then add " or " before last
	return strings.Join(versions[:len(versions)-1], ", ") + " or " + versions[len(versions)-1]
}

// sortVersionsDesc sorts version strings in descending order (newest first)
func sortVersionsDesc(versions []string) {
	sort.Slice(versions, func(i, j int) bool {
		return compareVersions(versions[i], versions[j]) > 0
	})
}

// sortVersionsAsc sorts version strings in ascending order
func sortVersionsAsc(versions []string) {
	sort.Slice(versions, func(i, j int) bool {
		return compareVersions(versions[i], versions[j]) < 0
	})
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
