import logging

from rich.logging import RichHandler

# Constants for log format and date format
LOG_FORMAT = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
DATE_FORMAT = "%Y-%m-%d %H:%M:%S"

# Default logger instance
logger = None


def setup_logger(log_level=logging.INFO):
    global logger
    if log_level == "DEBUG":
        log_level = logging.DEBUG

    logging.basicConfig(
        level=log_level,
        format=LOG_FORMAT,
        datefmt=DATE_FORMAT,
        handlers=[RichHandler()],
    )
    logger = logging.getLogger()
    return logger


def get_logger():
    if logger is None:
        raise ValueError(
            "Logger has not been configured yet. Call setup_logger() first."
        )
    return logger
