package types

// ServiceConfig holds configuration for an ICD service type
type ServiceConfig struct {
	ServiceType  string // e.g., "postgresql", "mysql"
	VariableName string // e.g., "postgresql_version", "edb_version"
}

// GetServiceConfig returns the configuration for a given service type
func GetServiceConfig(serviceType string) ServiceConfig {
	// Map service types to their variable names
	// Note: enterprisedb uses "edb_version" not "enterprisedb_version"
	variableNameMap := map[string]string{
		"postgresql":    "postgresql_version",
		"mysql":         "mysql_version",
		"redis":         "redis_version",
		"mongodb":       "mongodb_version",
		"elasticsearch": "elasticsearch_version",
		"etcd":          "etcd_version",
		"rabbitmq":      "rabbitmq_version",
		"enterprisedb":  "edb_version",
	}

	varName, ok := variableNameMap[serviceType]
	if !ok {
		// Default: use {service}_version pattern
		varName = serviceType + "_version"
	}

	return ServiceConfig{
		ServiceType:  serviceType,
		VariableName: varName,
	}
}

// VersionInfo represents extracted version information from a single source
type VersionInfo struct {
	Versions      []string `json:"versions"`
	LatestVersion string   `json:"latest_version"`
}

// ExtractResult is the output of the extract command
type ExtractResult struct {
	ServiceType  string       `json:"service_type"`
	VariableName string       `json:"variable_name"`
	VariablesTF  *VersionInfo `json:"variables_tf,omitempty"`
	IBMCatalog   *VersionInfo `json:"ibm_catalog,omitempty"`
	TestFile     *VersionInfo `json:"test_file,omitempty"`
	Skipped      []string     `json:"skipped,omitempty"`
	Errors       []string     `json:"errors,omitempty"`
}

// UpdateRequest specifies what versions to update
type UpdateRequest struct {
	ServiceType   string   // e.g., "postgresql"
	VariableName  string   // e.g., "postgresql_version"
	NewVersions   []string // All versions to set (e.g., ["13", "14", "15", "16", "17"])
	LatestVersion string   // New latest version (e.g., "17")
	RepoRoot      string   // Path to the repository root
}

// UpdateResult reports which files were updated
type UpdateResult struct {
	UpdatedFiles []string `json:"updated_files"`
	Errors       []string `json:"errors,omitempty"`
}
