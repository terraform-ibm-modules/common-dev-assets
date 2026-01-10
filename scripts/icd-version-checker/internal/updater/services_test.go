package updater

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/terraform-ibm-modules/common-dev-assets/scripts/icd-version-checker/internal/types"
)

// TestUpdateMultipleServices tests updating for different ICD services
func TestUpdateMultipleServices(t *testing.T) {
	tests := []struct {
		name         string
		variableName string
		content      string
		newVersions  []string
		latest       string
		wantContains []string
	}{
		{
			name:         "elasticsearch",
			variableName: "elasticsearch_version",
			content: `variable "elasticsearch_version" {
  type    = string
  default = null

  validation {
    condition = anytrue([
      var.elasticsearch_version == null,
      var.elasticsearch_version == "8.7",
      var.elasticsearch_version == "8.10",
    ])
    error_message = "Version must be 8.7 or 8.10."
  }
}`,
			newVersions: []string{"8.10", "8.12", "8.15", "8.17"},
			latest:      "8.17",
			wantContains: []string{
				`var.elasticsearch_version == "8.17"`,
				`var.elasticsearch_version == "8.15"`,
				`var.elasticsearch_version == "8.12"`,
				`var.elasticsearch_version == "8.10"`,
				`Version must be 8.10, 8.12, 8.15 or 8.17`,
			},
		},
		{
			name:         "mysql",
			variableName: "mysql_version",
			content: `variable "mysql_version" {
  type    = string
  default = null

  validation {
    condition = anytrue([
      var.mysql_version == null,
      var.mysql_version == "8.0",
    ])
    error_message = "Version must be 8.0."
  }
}`,
			newVersions: []string{"8.0", "8.4"},
			latest:      "8.4",
			wantContains: []string{
				`var.mysql_version == "8.4"`,
				`var.mysql_version == "8.0"`,
				`Version must be 8.0 or 8.4`,
			},
		},
	}

	updater := NewHCLUpdater()

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := &types.UpdateRequest{
				VariableName:  tt.variableName,
				NewVersions:   tt.newVersions,
				LatestVersion: tt.latest,
			}

			result, err := updater.UpdateContent(tt.content, req)
			require.NoError(t, err)

			for _, want := range tt.wantContains {
				assert.True(t, strings.Contains(result, want), "should contain: %s", want)
			}
		})
	}
}
