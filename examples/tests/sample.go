// Sample go code to verify go lint checks during precommits

package main

import (
	"encoding/json"
	"fmt"
)

func main() {
	// JSON data
	jsonData := `{"name": "subnet-1", "region": "au-syd", "tags": "Test-1"}`

	// Convert JSON to map
	var data map[string]interface{}
	err := json.Unmarshal([]byte(jsonData), &data)
	if err != nil {
		fmt.Println("Error:", err)
		return
	}

	// Print the map
	fmt.Println("Map from JSON:")
	fmt.Println(data)

	// Create a sample map
	mapData := map[string]interface{}{
		"name":   "subnet-2",
		"region": "jp-tok",
		"tags":   "Test-2",
	}

	// Convert map to JSON
	jsonBytes, err := json.Marshal(mapData)
	if err != nil {
		fmt.Println("Error:", err)
		return
	}

	// Print the JSON
	fmt.Println("\nJSON from Map:")
	fmt.Println(string(jsonBytes))
}
