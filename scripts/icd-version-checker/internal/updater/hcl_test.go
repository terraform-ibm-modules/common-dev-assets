package updater

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/terraform-ibm-modules/common-dev-assets/scripts/icd-version-checker/internal/types"
)

func TestHCLUpdater_UpdateContent(t *testing.T) {
	tests := []struct {
		name            string
		content         string
		req             *types.UpdateRequest
		wantContains    []string
		wantNotContains []string
		wantErr         bool
	}{
		{
			name: "add new version",
			content: `variable "postgresql_version" {
  type        = string
  description = "Version of the PostgreSQL instance."
  default     = null

  validation {
    condition = anytrue([
      var.postgresql_version == null,
      var.postgresql_version == "17",
      var.postgresql_version == "16",
      var.postgresql_version == "15",
    ])
    error_message = "Version must be 15, 16 or 17. If no value passed, the current ICD preferred version is used."
  }
}`,
			req: &types.UpdateRequest{
				VariableName:  "postgresql_version",
				NewVersions:   []string{"15", "16", "17", "18"},
				LatestVersion: "18",
			},
			wantContains: []string{
				`var.postgresql_version == "18"`,
				`var.postgresql_version == "17"`,
				`var.postgresql_version == "16"`,
				`var.postgresql_version == "15"`,
				`Version must be 15, 16, 17 or 18`,
			},
			wantNotContains: []string{},
			wantErr:         false,
		},
		{
			name: "remove deprecated version",
			content: `variable "postgresql_version" {
  type        = string
  default     = null

  validation {
    condition = anytrue([
      var.postgresql_version == null,
      var.postgresql_version == "17",
      var.postgresql_version == "16",
      var.postgresql_version == "15",
      var.postgresql_version == "14",
      var.postgresql_version == "13",
    ])
    error_message = "Version must be 13, 14, 15, 16 or 17. If no value passed, the current ICD preferred version is used."
  }
}`,
			req: &types.UpdateRequest{
				VariableName:  "postgresql_version",
				NewVersions:   []string{"15", "16", "17"},
				LatestVersion: "17",
			},
			wantContains: []string{
				`var.postgresql_version == "17"`,
				`var.postgresql_version == "16"`,
				`var.postgresql_version == "15"`,
				`Version must be 15, 16 or 17`,
			},
			wantNotContains: []string{
				`var.postgresql_version == "14"`,
				`var.postgresql_version == "13"`,
			},
			wantErr: false,
		},
		{
			name: "semver versions",
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
			req: &types.UpdateRequest{
				VariableName:  "mysql_version",
				NewVersions:   []string{"8.0", "8.4"},
				LatestVersion: "8.4",
			},
			wantContains: []string{
				`var.mysql_version == "8.4"`,
				`var.mysql_version == "8.0"`,
				`Version must be 8.0 or 8.4`,
			},
			wantErr: false,
		},
		{
			name: "variable not found",
			content: `variable "other_version" {
  type = string
}`,
			req: &types.UpdateRequest{
				VariableName: "postgresql_version",
				NewVersions:  []string{"17"},
			},
			wantErr: true,
		},
		{
			name: "only updates error_message in target variable",
			content: `variable "postgresql_version" {
  type        = string
  description = "Version of the PostgreSQL instance."
  default     = null

  validation {
    condition = anytrue([
      var.postgresql_version == null,
      var.postgresql_version == "17",
      var.postgresql_version == "16",
    ])
    error_message = "Version must be 16 or 17. If no value passed, the current ICD preferred version is used."
  }
}

variable "member_host_flavor" {
  type        = string
  description = "Allocated host flavor per member."
  default     = null

  validation {
    condition     = var.member_host_flavor == null || can(regex("^[a-z]+\\.[0-9]+x[0-9]+\\.encrypted$", var.member_host_flavor))
    error_message = "Invalid host flavor. Must be null or format like 'b3c.4x16.encrypted'."
  }
}

variable "users" {
  type = list(object({
    name     = string
    password = string
  }))
  description = "List of users"
  default     = []

  validation {
    condition     = length(var.users) >= 0
    error_message = "Users must be a valid list."
  }
}`,
			req: &types.UpdateRequest{
				VariableName:  "postgresql_version",
				NewVersions:   []string{"16", "17", "18"},
				LatestVersion: "18",
			},
			wantContains: []string{
				// Updated version variable
				`var.postgresql_version == "18"`,
				`var.postgresql_version == "17"`,
				`var.postgresql_version == "16"`,
				`Version must be 16, 17 or 18`,
				// Other variables' error_messages should be UNCHANGED
				`error_message = "Invalid host flavor. Must be null or format like 'b3c.4x16.encrypted'."`,
				`error_message = "Users must be a valid list."`,
			},
			wantNotContains: []string{},
			wantErr:         false,
		},
	}

	updater := NewHCLUpdater()

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := updater.UpdateContent(tt.content, tt.req)

			if tt.wantErr {
				assert.Error(t, err)
				return
			}

			require.NoError(t, err)

			for _, want := range tt.wantContains {
				assert.Contains(t, result, want, "should contain: %s", want)
			}

			for _, notWant := range tt.wantNotContains {
				assert.NotContains(t, result, notWant, "should not contain: %s", notWant)
			}
		})
	}
}

func TestFormatVersionList(t *testing.T) {
	tests := []struct {
		versions []string
		want     string
	}{
		{[]string{}, ""},
		{[]string{"17"}, "17"},
		{[]string{"16", "17"}, "16 or 17"},
		{[]string{"15", "16", "17"}, "15, 16 or 17"},
		{[]string{"13", "14", "15", "16", "17"}, "13, 14, 15, 16 or 17"},
	}

	for _, tt := range tests {
		t.Run(strings.Join(tt.versions, "_"), func(t *testing.T) {
			got := formatVersionList(tt.versions)
			assert.Equal(t, tt.want, got)
		})
	}
}

func TestSortVersionsDesc(t *testing.T) {
	versions := []string{"13", "17", "15", "14", "16"}
	sortVersionsDesc(versions)
	assert.Equal(t, []string{"17", "16", "15", "14", "13"}, versions)
}
