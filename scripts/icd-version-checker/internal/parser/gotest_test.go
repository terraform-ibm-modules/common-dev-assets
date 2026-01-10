package parser

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestGoTestParser_ParseContent(t *testing.T) {
	tests := []struct {
		name         string
		content      string
		variableName string
		wantLatest   string
		wantErr      bool
	}{
		{
			name: "standard format",
			content: `package test

import "testing"

const latestVersion = "17"

func TestSomething(t *testing.T) {}
`,
			variableName: "postgresql_version",
			wantLatest:   "17",
			wantErr:      false,
		},
		{
			name: "semver format",
			content: `package test

const latestVersion = "8.0"
`,
			variableName: "mysql_version",
			wantLatest:   "8.0",
			wantErr:      false,
		},
		{
			name: "multi-part semver",
			content: `package test

const latestVersion = "8.15"
`,
			variableName: "elasticsearch_version",
			wantLatest:   "8.15",
			wantErr:      false,
		},
		{
			name: "with other constants",
			content: `package test

const (
	someOther = "value"
)

const latestVersion = "16"
const anotherConst = "foo"
`,
			variableName: "postgresql_version",
			wantLatest:   "16",
			wantErr:      false,
		},
		{
			name: "fallback to variable name pattern - edb_version",
			content: `package test

func TestSomething(t *testing.T) {
	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		TerraformVars: map[string]interface{}{
			"edb_version": "12",
		},
	})
}
`,
			variableName: "edb_version",
			wantLatest:   "12",
			wantErr:      false,
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
			variableName: "redis_version",
			wantLatest:   "7.2",
			wantErr:      false,
		},
		{
			name: "no latestVersion constant and no fallback match",
			content: `package test

const otherVersion = "17"
`,
			variableName: "postgresql_version",
			wantErr:      true,
		},
		{
			name:         "empty content",
			content:      "",
			variableName: "postgresql_version",
			wantErr:      true,
		},
		{
			name:         "different spacing",
			content:      `const  latestVersion  =  "15"`,
			variableName: "postgresql_version",
			wantLatest:   "15",
			wantErr:      false,
		},
	}

	parser := NewGoTestParser()

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := parser.ParseContent(tt.content, tt.variableName)

			if tt.wantErr {
				assert.Error(t, err)
				return
			}

			require.NoError(t, err)
			assert.Equal(t, tt.wantLatest, result.LatestVersion)
			assert.Equal(t, []string{tt.wantLatest}, result.Versions)
		})
	}
}
