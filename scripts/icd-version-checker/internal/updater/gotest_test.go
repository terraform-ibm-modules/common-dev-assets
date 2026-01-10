package updater

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/terraform-ibm-modules/common-dev-assets/scripts/icd-version-checker/internal/types"
)

func TestGoTestUpdater_UpdateContent(t *testing.T) {
	tests := []struct {
		name    string
		content string
		req     *types.UpdateRequest
		want    string
		wantErr bool
	}{
		{
			name: "update simple version",
			content: `package test

const latestVersion = "17"

func TestSomething(t *testing.T) {}
`,
			req: &types.UpdateRequest{
				LatestVersion: "18",
			},
			want: `package test

const latestVersion = "18"

func TestSomething(t *testing.T) {}
`,
			wantErr: false,
		},
		{
			name: "update semver version",
			content: `package test

const latestVersion = "8.0"
`,
			req: &types.UpdateRequest{
				LatestVersion: "8.4",
			},
			want: `package test

const latestVersion = "8.4"
`,
			wantErr: false,
		},
		{
			name: "preserves other content",
			content: `package test

import "testing"

const (
	someConst = "value"
)

const latestVersion = "16"
const anotherConst = "foo"

func TestMain(m *testing.M) {
	// setup
}
`,
			req: &types.UpdateRequest{
				LatestVersion: "17",
			},
			want: `package test

import "testing"

const (
	someConst = "value"
)

const latestVersion = "17"
const anotherConst = "foo"

func TestMain(m *testing.M) {
	// setup
}
`,
			wantErr: false,
		},
		{
			name: "fallback to variable name pattern - edb_version",
			content: `package test

func TestSomething(t *testing.T) {
	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		TerraformVars: map[string]interface{}{
			"edb_version": "12", // Always lock this test into the latest supported Enterprise DB version
		},
	})
}
`,
			req: &types.UpdateRequest{
				VariableName:  "edb_version",
				LatestVersion: "15",
			},
			want: `package test

func TestSomething(t *testing.T) {
	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		TerraformVars: map[string]interface{}{
			"edb_version": "15", // Always lock this test into the latest supported Enterprise DB version
		},
	})
}
`,
			wantErr: false,
		},
		{
			name: "fallback to variable name pattern - redis_version",
			content: `package test

func TestSomething(t *testing.T) {
	options := map[string]interface{}{
		"redis_version": "7.2",
	}
}
`,
			req: &types.UpdateRequest{
				VariableName:  "redis_version",
				LatestVersion: "7.4",
			},
			want: `package test

func TestSomething(t *testing.T) {
	options := map[string]interface{}{
		"redis_version": "7.4",
	}
}
`,
			wantErr: false,
		},
		{
			name: "no latestVersion constant and no fallback match",
			content: `package test

const otherVersion = "17"
`,
			req: &types.UpdateRequest{
				VariableName:  "postgresql_version",
				LatestVersion: "18",
			},
			wantErr: true,
		},
		{
			name:    "empty content",
			content: "",
			req: &types.UpdateRequest{
				LatestVersion: "18",
			},
			wantErr: true,
		},
		{
			name: "update struct field pattern",
			content: `package test

func TestSomething(t *testing.T) {
	options := testschematic.TestSchematicOptionsDefault(&testschematic.TestSchematicOptions{
		Testing: t,
	})

	options.TerraformVars = []testschematic.TestSchematicTerraformVar{
		{Name: "prefix", Value: options.Prefix, DataType: "string"},
		{Name: "postgresql_version", Value: "16", DataType: "string"}, // Always lock this test into the latest supported PostgresSQL version
		{Name: "other_var", Value: "foo", DataType: "string"},
	}
}
`,
			req: &types.UpdateRequest{
				VariableName:  "postgresql_version",
				LatestVersion: "18",
			},
			want: `package test

func TestSomething(t *testing.T) {
	options := testschematic.TestSchematicOptionsDefault(&testschematic.TestSchematicOptions{
		Testing: t,
	})

	options.TerraformVars = []testschematic.TestSchematicTerraformVar{
		{Name: "prefix", Value: options.Prefix, DataType: "string"},
		{Name: "postgresql_version", Value: "18", DataType: "string"}, // Always lock this test into the latest supported PostgresSQL version
		{Name: "other_var", Value: "foo", DataType: "string"},
	}
}
`,
			wantErr: false,
		},
		{
			name: "update all three patterns together",
			content: `package test

const latestVersion = "16"

func TestOne(t *testing.T) {
	options.TerraformVars = []testschematic.TestSchematicTerraformVar{
		{Name: "postgresql_version", Value: "16", DataType: "string"},
		{Name: "other", Value: "foo", DataType: "string"},
	}
}

func TestTwo(t *testing.T) {
	vars := map[string]interface{}{
		"postgresql_version": "16",
	}
}
`,
			req: &types.UpdateRequest{
				VariableName:  "postgresql_version",
				LatestVersion: "18",
			},
			want: `package test

const latestVersion = "18"

func TestOne(t *testing.T) {
	options.TerraformVars = []testschematic.TestSchematicTerraformVar{
		{Name: "postgresql_version", Value: "18", DataType: "string"},
		{Name: "other", Value: "foo", DataType: "string"},
	}
}

func TestTwo(t *testing.T) {
	vars := map[string]interface{}{
		"postgresql_version": "18",
	}
}
`,
			wantErr: false,
		},
	}

	updater := NewGoTestUpdater()

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := updater.UpdateContent(tt.content, tt.req)

			if tt.wantErr {
				assert.Error(t, err)
				return
			}

			require.NoError(t, err)
			assert.Equal(t, tt.want, result)
		})
	}
}
