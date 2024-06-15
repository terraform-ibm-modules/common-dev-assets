from dataclasses import dataclass, field
from enum import Enum
from typing import Optional


class State(Enum):
    VALIDATED = "validated"
    DEPLOYED = "deployed"
    DRAFT = "draft"
    DEPLOYING_FAILED = "deploying_failed"
    APPROVED = "approved"
    DELETING = "deleting"
    DELETING_FAILED = "deleting_failed"
    DEPLOYING = "deploying"
    VALIDATING = "validating"
    DELETED = "deleted"
    DISCARDED = "discarded"
    SUPERSEDED = "superseded"
    UNDEPLOYING = "undeploying"
    UNDEPLOYING_FAILED = "undeploying_failed"
    VALIDATING_FAILED = "validating_failed"
    APPLIED = "applied"
    APPLY_FAILED = "apply_failed"
    UNKNOWN = "unknown"  # unknown state, custom not in the API


class StateCode(Enum):
    AWAITING_VALIDATION = "awaiting_validation"
    AWAITING_PREREQUISITE = "awaiting_prerequisite"
    AWAITING_INPUT = "awaiting_input"
    AWAITING_MEMBER_DEPLOYMENT = "awaiting_member_deployment"
    AWAITING_STACK_SETUP = "awaiting_stack_setup"
    AWAITING_APPROVAL = "awaiting_approval"
    AWAITING_DEPLOYMENT = "awaiting_deployment"
    AWAITING_DELETION = "awaiting_deletion"
    AWAITING_UNDEPLOYMENT = "awaiting_undeployment"
    UNKNOWN = "unknown"  # unknown state, custom not in the API


DEPLOYABLE_STATES = {State.DEPLOYED, State.DEPLOYING_FAILED, State.UNDEPLOYING_FAILED}
VALIDATION_STATES = {
    State.DEPLOYED,
    State.DEPLOYING_FAILED,
    State.VALIDATED,
    State.APPROVED,
}
READY_STATE = {
    State.DEPLOYING_FAILED,
    State.VALIDATING_FAILED,
    State.APPLY_FAILED,
    State.VALIDATED,
    State.APPROVED,
}

NOT_LOG_IN = "Not logged in"
TLS_TIMEOUT = "tls handshake timeout"
MAX_RETRY_COUNT = 5

# Configuration specific constants
PROJECT_NAME = "project_name"
STACK_NAME = "stack_name"
CONFIG_ORDER = "config_order"
STACK_DEF_PATH = "stack_def_path"
STACK_INPUTS = "stack_inputs"
STACK_API_KEY_ENV = "stack_api_key_env"

PDE = "****************** PARALLEL DEPLOYMENT ERROR ******************"

# Tools and others
IBMCLOUD = "ibmcloud"
PROJECT = "project"

ERR_OCCURRED = False


@dataclass
class CLIConfig:
    project_name: Optional[str] = field(
        default=None,
        metadata={"args": ["-p", "--project_name"], "help": "The project name"},
    )
    stack_name: Optional[str] = field(
        default=None,
        metadata={"args": ["-s", "--stack_name"], "help": "The stack name"},
    )
    config_order: Optional[str] = field(
        default=None,
        metadata={
            "args": ["-o", "--config_order"],
            "help": 'The config names in order to be deployed in the format "config1|config2|config3"',
        },
    )
    stack_def_path: str = field(
        default="stack_definition.json",
        metadata={
            "args": ["--stack_def_path"],
            "help": "The path to the stack definition json file",
        },
    )
    config_json_path: Optional[str] = field(
        default=None,
        metadata={
            "args": ["-c", "--config_json_path"],
            "help": "The path to the config json file",
        },
    )
    undeploy: bool = field(
        default=False,
        metadata={
            "args": ["-u", "--undeploy"],
            "action": "store_true",
            "help": "Undeploy the stack",
        },
    )
    stack_inputs: Optional[str] = field(
        default=None,
        metadata={
            "args": ["--stack_inputs"],
            "help": 'Stack inputs as json string {"inputs":{"input1":"value1", "input2":"value2"}}',
        },
    )
    stack_api_key_env: str = field(
        default="IBMCLOUD_API_KEY",
        metadata={
            "args": ["--stack_api_key_env"],
            "help": "The environment variable name for the stack api key",
        },
    )
    skip_stack_inputs: bool = field(
        default=False,
        metadata={
            "args": ["--skip_stack_inputs"],
            "action": "store_true",
            "help": "Skip setting stack inputs",
        },
    )
    stack_definition_update: bool = field(
        default=False,
        metadata={
            "args": ["--stack_definition_update"],
            "action": "store_true",
            "help": "Updating stack definition",
        },
    )
    parallel: bool = field(
        default=False,
        metadata={
            "args": ["--parallel"],
            "action": "store_true",
            "help": "Deploy configurations in parallel",
        },
    )
    debug: bool = field(
        default=False,
        metadata={
            "args": ["--debug"],
            "action": "store_true",
            "help": "Enable debug mode",
        },
    )
