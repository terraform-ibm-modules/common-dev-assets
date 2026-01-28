package parser

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestMultipleServices tests parsing for all ICD service types
func TestMultipleServices(t *testing.T) {
	tests := []struct {
		name         string
		serviceType  string
		variableName string
		hclContent   string
		wantVersions []string
		wantLatest   string
	}{
		{
			name:         "postgresql",
			serviceType:  "postgresql",
			variableName: "postgresql_version",
			hclContent: `variable "postgresql_version" {
  validation {
    condition = anytrue([
      var.postgresql_version == null,
      var.postgresql_version == "17",
      var.postgresql_version == "16",
      var.postgresql_version == "15",
    ])
  }
}`,
			wantVersions: []string{"15", "16", "17"},
			wantLatest:   "17",
		},
		{
			name:         "mysql",
			serviceType:  "mysql",
			variableName: "mysql_version",
			hclContent: `variable "mysql_version" {
  validation {
    condition = anytrue([
      var.mysql_version == null,
      var.mysql_version == "8.0",
    ])
  }
}`,
			wantVersions: []string{"8.0"},
			wantLatest:   "8.0",
		},
		{
			name:         "redis",
			serviceType:  "redis",
			variableName: "redis_version",
			hclContent: `variable "redis_version" {
  validation {
    condition = anytrue([
      var.redis_version == null,
      var.redis_version == "7.2",
    ])
  }
}`,
			wantVersions: []string{"7.2"},
			wantLatest:   "7.2",
		},
		{
			name:         "mongodb",
			serviceType:  "mongodb",
			variableName: "mongodb_version",
			hclContent: `variable "mongodb_version" {
  validation {
    condition = anytrue([
      var.mongodb_version == null,
      var.mongodb_version == "6.0",
    ])
  }
}`,
			wantVersions: []string{"6.0"},
			wantLatest:   "6.0",
		},
		{
			name:         "elasticsearch",
			serviceType:  "elasticsearch",
			variableName: "elasticsearch_version",
			hclContent: `variable "elasticsearch_version" {
  validation {
    condition = anytrue([
      var.elasticsearch_version == null,
      var.elasticsearch_version == "8.7",
      var.elasticsearch_version == "8.10",
      var.elasticsearch_version == "8.12",
      var.elasticsearch_version == "8.15",
    ])
  }
}`,
			wantVersions: []string{"8.7", "8.10", "8.12", "8.15"},
			wantLatest:   "8.15",
		},
		{
			name:         "etcd",
			serviceType:  "etcd",
			variableName: "etcd_version",
			hclContent: `variable "etcd_version" {
  validation {
    condition = anytrue([
      var.etcd_version == null,
      var.etcd_version == "3.5",
      var.etcd_version == "3.4",
    ])
  }
}`,
			wantVersions: []string{"3.4", "3.5"},
			wantLatest:   "3.5",
		},
		{
			name:         "rabbitmq",
			serviceType:  "rabbitmq",
			variableName: "rabbitmq_version",
			hclContent: `variable "rabbitmq_version" {
  validation {
    condition = anytrue([
      var.rabbitmq_version == null,
      var.rabbitmq_version == "3.13",
      var.rabbitmq_version == "4.0",
    ])
  }
}`,
			wantVersions: []string{"3.13", "4.0"},
			wantLatest:   "4.0",
		},
		{
			name:         "enterprisedb (edb)",
			serviceType:  "enterprisedb",
			variableName: "edb_version",
			hclContent: `variable "edb_version" {
  validation {
    condition = anytrue([
      var.edb_version == null,
      var.edb_version == "12",
    ])
  }
}`,
			wantVersions: []string{"12"},
			wantLatest:   "12",
		},
	}

	hclParser := NewHCLParser()

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := hclParser.ParseContent(tt.hclContent, tt.variableName)
			require.NoError(t, err)
			assert.Equal(t, tt.wantVersions, result.Versions)
			assert.Equal(t, tt.wantLatest, result.LatestVersion)
		})
	}
}

// TestCatalogMultipleServices tests catalog parsing for different services
func TestCatalogMultipleServices(t *testing.T) {
	tests := []struct {
		name         string
		variableName string
		content      string
		wantVersions []string
		wantLatest   string
	}{
		{
			name:         "mysql single version",
			variableName: "mysql_version",
			content: `{
  "products": [{
    "flavors": [{
      "configuration": [{
        "key": "mysql_version",
        "default_value": "8.0",
        "options": [{"displayname": "8.0", "value": "8.0"}]
      }]
    }]
  }]
}`,
			wantVersions: []string{"8.0"},
			wantLatest:   "8.0",
		},
		{
			name:         "elasticsearch - default_value differs from latest",
			variableName: "elasticsearch_version",
			content: `{
  "products": [{
    "flavors": [{
      "configuration": [{
        "key": "elasticsearch_version",
        "default_value": "8.19",
        "options": [
          {"displayname": "8.10", "value": "8.10"},
          {"displayname": "8.12", "value": "8.12"},
          {"displayname": "8.15", "value": "8.15"},
          {"displayname": "8.19", "value": "8.19"},
          {"displayname": "9.1", "value": "9.1"}
        ]
      }]
    }]
  }]
}`,
			wantVersions: []string{"8.10", "8.12", "8.15", "8.19", "9.1"},
			wantLatest:   "9.1", // Should be highest, NOT default_value (8.19)
		},
		{
			name:         "redis - no options array, only default_value",
			variableName: "redis_version",
			content: `{
  "products": [{
    "flavors": [{
      "configuration": [{
        "key": "redis_version",
        "hidden": true,
        "default_value": "7.2"
      }]
    }]
  }]
}`,
			wantVersions: []string{"7.2"},
			wantLatest:   "7.2",
		},
	}

	catalogParser := NewCatalogParser()

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := catalogParser.ParseContent([]byte(tt.content), tt.variableName)
			require.NoError(t, err)
			assert.Equal(t, tt.wantVersions, result.Versions)
			assert.Equal(t, tt.wantLatest, result.LatestVersion)
		})
	}
}
