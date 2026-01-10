package updater

import (
	"fmt"
	"os"
	"regexp"

	"github.com/terraform-ibm-modules/common-dev-assets/scripts/icd-version-checker/internal/types"
)

// GoTestUpdater updates version information in Go test files
type GoTestUpdater struct{}

// NewGoTestUpdater creates a new Go test file updater
func NewGoTestUpdater() *GoTestUpdater {
	return &GoTestUpdater{}
}

// Update modifies the pr_test.go file with the new latest version
func (u *GoTestUpdater) Update(filePath string, req *types.UpdateRequest) error {
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

// UpdateContent updates the latestVersion constant in Go source content
// Updates multiple patterns: const latestVersion, struct field values, and inline versions
func (u *GoTestUpdater) UpdateContent(content string, req *types.UpdateRequest) (string, error) {
	updated := false

	// Pattern 1: const latestVersion = "17"
	constPattern := `(const\s+latestVersion\s*=\s*)"[0-9]+(?:\.[0-9]+)*"`
	constRe := regexp.MustCompile(constPattern)
	if constRe.MatchString(content) {
		replacement := fmt.Sprintf(`${1}"%s"`, req.LatestVersion)
		content = constRe.ReplaceAllString(content, replacement)
		updated = true
	}

	// Pattern 2: {Name: "postgresql_version", Value: "16", DataType: "string"}
	// Update all hardcoded version values in test structs
	if req.VariableName != "" {
		structPattern := fmt.Sprintf(`(\{Name: "%s", Value: )"[0-9]+(?:\.[0-9]+)*"(, DataType: "string"\})`, regexp.QuoteMeta(req.VariableName))
		structRe := regexp.MustCompile(structPattern)
		if structRe.MatchString(content) {
			replacement := fmt.Sprintf(`${1}"%s"${2}`, req.LatestVersion)
			content = structRe.ReplaceAllString(content, replacement)
			updated = true
		}

		// Pattern 3: "postgresql_version": "17" (inline map values)
		mapPattern := fmt.Sprintf(`("%s"\s*:\s*)"[0-9]+(?:\.[0-9]+)*"`, regexp.QuoteMeta(req.VariableName))
		mapRe := regexp.MustCompile(mapPattern)
		if mapRe.MatchString(content) {
			replacement := fmt.Sprintf(`${1}"%s"`, req.LatestVersion)
			content = mapRe.ReplaceAllString(content, replacement)
			updated = true
		}
	}

	if !updated {
		return "", fmt.Errorf("latestVersion constant not found")
	}

	return content, nil
}
