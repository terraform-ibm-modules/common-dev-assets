ALL_PAGES = " --all-pages"
JSON_OUTPUT = " --output json"
SHOW_ACCOUNT = "ibmcloud account show"
LOGIN = "ibmcloud login --apikey {api_key} {region}"
PROJECTS = "ibmcloud project "
PROJECTS_LIST = PROJECTS + "list" + ALL_PAGES + JSON_OUTPUT
PROJECTS_CONFIGS = (
    PROJECTS + "configs --project-id {project_id}" + ALL_PAGES + JSON_OUTPUT
)
PROJECT_CONFIG = (
    PROJECTS + "config --project-id {project_id} --id {config_id}" + JSON_OUTPUT
)
DEPLOY_CONFIG = PROJECTS + "config-deploy --project-id {project_id} --id {config_id}"
# ibmcloud project config --project-id {project_id} --id {config_id} --output json'
