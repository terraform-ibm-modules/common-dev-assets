class DeploymentError(Exception):
    pass


class ValidationError(Exception):
    pass


class ApprovalError(Exception):
    pass


class ProjectNotFoundError(Exception):
    pass


class ConfigNotFoundError(Exception):
    pass


class StackNotFoundError(Exception):
    pass
