package updater

import (
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/terraform-ibm-modules/common-dev-assets/scripts/icd-version-checker/internal/types"
)

func TestCatalogUpdater_UpdateContent(t *testing.T) {
	tests := []struct {
		name    string
		content string
		req     *types.UpdateRequest
		verify  func(t *testing.T, result []byte)
		wantErr bool
	}{
		{
			name: "update postgresql versions",
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
			req: &types.UpdateRequest{
				VariableName:  "postgresql_version",
				NewVersions:   []string{"16", "17", "18"},
				LatestVersion: "18",
			},
			verify: func(t *testing.T, result []byte) {
				var catalog map[string]interface{}
				err := json.Unmarshal(result, &catalog)
				require.NoError(t, err)

				// Navigate to configuration
				products := catalog["products"].([]interface{})
				flavors := products[0].(map[string]interface{})["flavors"].([]interface{})
				config := flavors[0].(map[string]interface{})["configuration"].([]interface{})
				versionConfig := config[0].(map[string]interface{})

				// Check default_value
				assert.Equal(t, "18", versionConfig["default_value"])

				// Check options
				options := versionConfig["options"].([]interface{})
				assert.Len(t, options, 3)
				assert.Equal(t, "16", options[0].(map[string]interface{})["value"])
				assert.Equal(t, "17", options[1].(map[string]interface{})["value"])
				assert.Equal(t, "18", options[2].(map[string]interface{})["value"])
			},
			wantErr: false,
		},
		{
			name: "key not found",
			content: `{
  "products": [
    {
      "flavors": [
        {
          "configuration": [
            {"key": "other_key"}
          ]
        }
      ]
    }
  ]
}`,
			req: &types.UpdateRequest{
				VariableName:  "postgresql_version",
				NewVersions:   []string{"17"},
				LatestVersion: "17",
			},
			wantErr: true,
		},
		{
			name:    "invalid JSON",
			content: `not valid json`,
			req: &types.UpdateRequest{
				VariableName: "postgresql_version",
			},
			wantErr: true,
		},
	}

	updater := NewCatalogUpdater()

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := updater.UpdateContent([]byte(tt.content), tt.req)

			if tt.wantErr {
				assert.Error(t, err)
				return
			}

			require.NoError(t, err)
			if tt.verify != nil {
				tt.verify(t, result)
			}
		})
	}
}
