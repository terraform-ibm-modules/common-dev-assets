package parser

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestHCLParser_ParseContent(t *testing.T) {
	tests := []struct {
		name         string
		content      string
		variableName string
		wantVersions []string
		wantLatest   string
		wantErr      bool
	}{
		{
			name: "postgresql multiple versions",
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
      var.postgresql_version == "14",
      var.postgresql_version == "13",
    ])
    error_message = "Version must be 13, 14, 15, 16 or 17."
  }
}`,
			variableName: "postgresql_version",
			wantVersions: []string{"13", "14", "15", "16", "17"},
			wantLatest:   "17",
			wantErr:      false,
		},
		{
			name: "mysql single version",
			content: `variable "mysql_version" {
  type        = string
  default     = null

  validation {
    condition = anytrue([
      var.mysql_version == null,
      var.mysql_version == "8.0",
    ])
    error_message = "Version must be 8.0."
  }
}`,
			variableName: "mysql_version",
			wantVersions: []string{"8.0"},
			wantLatest:   "8.0",
			wantErr:      false,
		},
		{
			name: "elasticsearch multiple semver versions",
			content: `variable "elasticsearch_version" {
  type        = string
  default     = null

  validation {
    condition = anytrue([
      var.elasticsearch_version == null,
      var.elasticsearch_version == "8.7",
      var.elasticsearch_version == "8.10",
      var.elasticsearch_version == "8.12",
      var.elasticsearch_version == "8.15",
    ])
    error_message = "Version must be one of the supported versions."
  }
}`,
			variableName: "elasticsearch_version",
			wantVersions: []string{"8.7", "8.10", "8.12", "8.15"},
			wantLatest:   "8.15",
			wantErr:      false,
		},
		{
			name: "no versions found",
			content: `variable "other_var" {
  type = string
}`,
			variableName: "postgresql_version",
			wantErr:      true,
		},
		{
			name:         "empty content",
			content:      "",
			variableName: "postgresql_version",
			wantErr:      true,
		},
	}

	parser := NewHCLParser()

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := parser.ParseContent(tt.content, tt.variableName)

			if tt.wantErr {
				assert.Error(t, err)
				return
			}

			require.NoError(t, err)
			assert.Equal(t, tt.wantVersions, result.Versions)
			assert.Equal(t, tt.wantLatest, result.LatestVersion)
		})
	}
}

func TestCompareVersions(t *testing.T) {
	tests := []struct {
		a, b string
		want int
	}{
		{"13", "14", -1},
		{"17", "16", 1},
		{"15", "15", 0},
		{"8.0", "8.1", -1},
		{"8.10", "8.7", 1},  // 10 > 7
		{"8.10", "8.10", 0},
		{"8", "8.0", 0},
	}

	for _, tt := range tests {
		t.Run(tt.a+"_vs_"+tt.b, func(t *testing.T) {
			got := compareVersions(tt.a, tt.b)
			assert.Equal(t, tt.want, got)
		})
	}
}

func TestSortVersions(t *testing.T) {
	tests := []struct {
		name     string
		input    []string
		expected []string
	}{
		{
			name:     "simple integers",
			input:    []string{"16", "13", "17", "14", "15"},
			expected: []string{"13", "14", "15", "16", "17"},
		},
		{
			name:     "semver versions",
			input:    []string{"8.15", "8.7", "8.12", "8.10"},
			expected: []string{"8.7", "8.10", "8.12", "8.15"},
		},
		{
			name:     "mixed",
			input:    []string{"3.5", "3.4"},
			expected: []string{"3.4", "3.5"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			sortVersions(tt.input)
			assert.Equal(t, tt.expected, tt.input)
		})
	}
}
