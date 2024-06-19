# Stack Deployment Script
This script is used to validate, approve, and deploy configurations for a project in IBM Cloud. It can also undeploy configurations if needed.

### Prerequisites
- Python 3
- IBM Cloud CLI
- IBM Cloud Project plugin
- Projects should be created from UI (using tile)
- Configuration should be added to the Projects from UI

### Usage
Clone the repository and navigate to the directory containing the script.


Run `pip install requirements.txt`

Set the necessary environment variables, default variable is `IBMCLOUD_API_KEY` but this can be configured in the config file.:
```bash
export IBMCLOUD_API_KEY=<your_ibmcloud_api_key>
```
Run the script:
```bash
python stackDeploy.py --project_name <project_name> --stack_name <stack_name> --config_order <config_order>
```
Replace <project_name>, <stack_name>, and <config_order> with your specific values.

Or with config file:
```bash
python stackDeploy.py --config_json_path <config_json_path>
```

The script will deploy the configurations in the order specified in the config_order argument.

If using the `--parallel` flag, the script will attempt to deploy the configurations in parallel if possible.
It will attempt to deploy prerequisites first, then deploy the remaining configurations in parallel.
If a configuration has a dependency on another configuration, it will wait for the dependency to complete before deploying.
**NOTE:** Use parallel with caution, It always works on a fresh deployment, but it could run with unexpected results if existing configurations are in unexpected states. If in doubt, do not use parallel.


### Undeploy
To undeploy a stack, run the script with the `--undeploy` flag:
```python stackDeploy.py --project_name <project_name> --stack_name <stack_name> --config_order <config_order> --undeploy```
or
```python stackDeploy.py --config_json_path <config_json_path> --undeploy```

The script will undeploy in reverse order of the config_order argument sequentially, as the reverse order is the safest way to undeploy configurations.

### Arguments
Arguments will take precedence over settings in the config file.
- `-p <PROJECT_NAME>, --project_name <PROJECT_NAME>`: The project name (can be set in the config file)
- `-s <STACK_NAME>, --stack_name <STACK_NAME>`: The stack name (can be set in the config file)
- `-o <CONFIG_ORDER>, --config_order <CONFIG_ORDER>`: The config names in order to be deployed in the format "config1|config2|config3" (can be set in the config file)
- `--stack_def_path <STACK_DEF_PATH>`: The path to the stack definition json file (can be set in the config file)
- `--stack_inputs <STACK_INPUTS>`: Stack inputs as json string {"inputs":{"input1":"value1", "input2":"value2"}} (can be set in the config file)
- `--stack_api_key_env <STACK_API_KEY_ENV>`: The environment variable name for the stack api key to deploy with. Default `IBMCLOUD_API_KEY` (can be set in the config file)
- `-c <CONFIG_JSON_PATH>, --config_json_path <CONFIG_JSON_PATH>`: The path to the config json file
- `--skip_stack_inputs`: Skip setting stack inputs
- `-u, --undeploy`: Undeploy the stack
- `--debug`: Enable debug mode
- `--parallel`: Deploy configurations in parallel
- `--help`: Show help message

### Sample Config File
```json
{
    "project_name": "my_project",
    "stack_name": "my_stack",
    "stack_api_key_env": "IBMCLOUD_API_KEY",
    "config_order": [
        "config1",
        "config2",
        "config3"],
    "stack_def_path": "stack_definition.json",
    "stack_inputs": {
        "input1":"value1",
        "input2":"value2",
        "ibmcloud_api_key": "API_KEY"
    }
}
```
- `project_name`: The name of your project.
- `stack_name`: The name of your stack.
- `config_order`: An array of configuration names in the order they should be deployed.
- `stack_def_path`: The path to the stack definition JSON file.
- `stack_inputs`: A dictionary of stack inputs. NOTE: if a key is set to `API_KEY` it will be replaced with the value of the `stack_api_key_env` environment variable.
- `config_json_path`: The path to the configuration JSON file.
- `stack_api_key_env`: The environment variable name for the stack API key to deploy with.


### Troubleshooting
If you encounter any errors, check the logs for detailed error messages.
If the error is related to a specific configuration, the error message will include the configuration ID.
The debug flag can be used to print additional information to the console.

If a failure occurs sometimes running the deployment script again will resolve the issue. Ensure the `--skip_stack_inputs` flag is enabled and the script will skip configurations that have already been deployed.
