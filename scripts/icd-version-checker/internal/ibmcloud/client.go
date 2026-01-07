package ibmcloud

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"sort"
	"strings"
	"time"
)

// Client handles IBM Cloud API interactions
type Client struct {
	apiKey     string
	httpClient *http.Client
	token      string
	tokenExp   time.Time
}

// NewClient creates a new IBM Cloud API client
func NewClient(apiKey string) *Client {
	return &Client{
		apiKey: apiKey,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// IAMTokenResponse represents the IAM token response
type IAMTokenResponse struct {
	AccessToken string `json:"access_token"`
	ExpiresIn   int    `json:"expires_in"`
}

// DeployablesResponse represents the deployables API response
type DeployablesResponse struct {
	Deployables []Deployable `json:"deployables"`
}

// Deployable represents a deployable database type
type Deployable struct {
	Type     string    `json:"type"`
	Versions []Version `json:"versions"`
}

// Version represents a database version
type Version struct {
	Version    string `json:"version"`
	Status     string `json:"status"`
	IsPreferred bool   `json:"is_preferred"`
}

// getToken obtains an IAM access token
func (c *Client) getToken() (string, error) {
	// Return cached token if still valid
	if c.token != "" && time.Now().Before(c.tokenExp) {
		return c.token, nil
	}

	data := url.Values{}
	data.Set("grant_type", "urn:ibm:params:oauth:grant-type:apikey")
	data.Set("apikey", c.apiKey)

	req, err := http.NewRequest("POST", "https://iam.cloud.ibm.com/identity/token", strings.NewReader(data.Encode()))
	if err != nil {
		return "", fmt.Errorf("failed to create token request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to get token: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("token request failed (%d): %s", resp.StatusCode, string(body))
	}

	var tokenResp IAMTokenResponse
	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		return "", fmt.Errorf("failed to decode token response: %w", err)
	}

	c.token = tokenResp.AccessToken
	c.tokenExp = time.Now().Add(time.Duration(tokenResp.ExpiresIn-60) * time.Second)

	return c.token, nil
}

// GetDeployableVersions fetches available versions for a service type
func (c *Client) GetDeployableVersions(serviceType string) ([]string, string, error) {
	token, err := c.getToken()
	if err != nil {
		return nil, "", err
	}

	// Use us-south region for API
	apiURL := "https://api.us-south.databases.cloud.ibm.com/v5/ibm/deployables"

	req, err := http.NewRequest("GET", apiURL, nil)
	if err != nil {
		return nil, "", fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+token)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, "", fmt.Errorf("failed to fetch deployables: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, "", fmt.Errorf("deployables request failed (%d): %s", resp.StatusCode, string(body))
	}

	var deployablesResp DeployablesResponse
	if err := json.NewDecoder(resp.Body).Decode(&deployablesResp); err != nil {
		return nil, "", fmt.Errorf("failed to decode deployables response: %w", err)
	}

	// Find the matching service type
	// Map service types to API names
	apiServiceName := mapServiceType(serviceType)

	var versions []string
	var preferredVersion string

	for _, dep := range deployablesResp.Deployables {
		if strings.EqualFold(dep.Type, apiServiceName) {
			for _, v := range dep.Versions {
				if v.Status == "stable" || v.Status == "" {
					versions = append(versions, v.Version)
					if v.IsPreferred {
						preferredVersion = v.Version
					}
				}
			}
			break
		}
	}

	if len(versions) == 0 {
		return nil, "", fmt.Errorf("no versions found for service type: %s", serviceType)
	}

	// Sort versions
	sort.Slice(versions, func(i, j int) bool {
		return compareVersions(versions[i], versions[j]) < 0
	})

	// If no preferred version, use the latest
	if preferredVersion == "" {
		preferredVersion = versions[len(versions)-1]
	}

	return versions, preferredVersion, nil
}

// mapServiceType maps our service type names to IBM Cloud API names
func mapServiceType(serviceType string) string {
	mapping := map[string]string{
		"postgresql":    "postgresql",
		"mysql":         "mysql",
		"redis":         "redis",
		"mongodb":       "mongodb",
		"elasticsearch": "elasticsearch",
		"etcd":          "etcd",
		"rabbitmq":      "rabbitmq",
		"enterprisedb":  "enterprisedb",
	}
	if name, ok := mapping[serviceType]; ok {
		return name
	}
	return serviceType
}

// compareVersions compares two version strings
func compareVersions(a, b string) int {
	partsA := strings.Split(a, ".")
	partsB := strings.Split(b, ".")

	maxLen := len(partsA)
	if len(partsB) > maxLen {
		maxLen = len(partsB)
	}

	for i := 0; i < maxLen; i++ {
		var numA, numB int
		if i < len(partsA) {
			fmt.Sscanf(partsA[i], "%d", &numA)
		}
		if i < len(partsB) {
			fmt.Sscanf(partsB[i], "%d", &numB)
		}

		if numA < numB {
			return -1
		}
		if numA > numB {
			return 1
		}
	}
	return 0
}
