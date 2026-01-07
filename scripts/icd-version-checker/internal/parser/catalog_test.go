package parser

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestCatalogParser_ParseContent(t *testing.T) {
	tests := []struct {
		name         string
		content      string
		variableName string
		wantVersions []string
		wantLatest   string
		wantErr      bool
	}{
		{
			name: "postgresql versions",
			content: `{
  "products": [
    {
      "flavors": [
        {
          "name": "fully-configurable",
          "configuration": [
            {
              "key": "postgresql_version",
              "required": true,
              "default_value": "17",
              "options": [
                {"displayname": "13", "value": "13"},
                {"displayname": "14", "value": "14"},
                {"displayname": "15", "value": "15"},
                {"displayname": "16", "value": "16"},
                {"displayname": "17", "value": "17"}
              ]
            }
          ]
        }
      ]
    }
  ]
}`,
			variableName: "postgresql_version",
			wantVersions: []string{"13", "14", "15", "16", "17"},
			wantLatest:   "17",
			wantErr:      false,
		},
		{
			name: "mysql single version",
			content: `{
  "products": [
    {
      "flavors": [
        {
          "name": "standard",
          "configuration": [
            {
              "key": "mysql_version",
              "default_value": "8.0",
              "options": [
                {"displayname": "8.0", "value": "8.0"}
              ]
            }
          ]
        }
      ]
    }
  ]
}`,
			variableName: "mysql_version",
			wantVersions: []string{"8.0"},
			wantLatest:   "8.0",
			wantErr:      false,
		},
		{
			name: "variable not found",
			content: `{
  "products": [
    {
      "flavors": [
        {
          "name": "standard",
          "configuration": [
            {"key": "other_key"}
          ]
        }
      ]
    }
  ]
}`,
			variableName: "postgresql_version",
			wantErr:      true,
		},
		{
			name:         "invalid JSON",
			content:      `not valid json`,
			variableName: "postgresql_version",
			wantErr:      true,
		},
		{
			name: "no options - falls back to default_value",
			content: `{
  "products": [
    {
      "flavors": [
        {
          "configuration": [
            {"key": "postgresql_version", "default_value": "17"}
          ]
        }
      ]
    }
  ]
}`,
			variableName: "postgresql_version",
			wantVersions: []string{"17"},
			wantLatest:   "17",
			wantErr:      false,
		},
		{
			name: "no options and no default_value",
			content: `{
  "products": [
    {
      "flavors": [
        {
          "configuration": [
            {"key": "postgresql_version"}
          ]
        }
      ]
    }
  ]
}`,
			variableName: "postgresql_version",
			wantErr:      true,
		},
	}

	parser := NewCatalogParser()

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := parser.ParseContent([]byte(tt.content), tt.variableName)

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
