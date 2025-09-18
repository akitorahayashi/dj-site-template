import os
import subprocess
import time
import socket
from pathlib import Path

import pytest
import requests
from dotenv import load_dotenv


def _is_service_ready(url: str, expected_status: int = 200) -> bool:
    """Check if HTTP service is ready by making a request."""
    try:
        response = requests.get(url, timeout=5)
        return response.status_code == expected_status
    except Exception:
        return False


def _wait_for_service(url: str, timeout: int = 120, interval: int = 5) -> None:
    """Wait for HTTP service to be ready with timeout."""
    start_time = time.time()
    while time.time() - start_time < timeout:
        if _is_service_ready(url):
            return
        time.sleep(interval)
    raise TimeoutError(
        f"Service at {url} did not become ready within {timeout} seconds"
    )


@pytest.fixture(scope="session")
def app_container():
    """
    Provides a fully running application stack via Docker Compose using subprocess.
    """
    load_dotenv(".env")

    # Find the project root by looking for a known file, e.g., pyproject.toml
    project_root = Path(__file__).parent.parent.parent

    # Get the test port from environment variable
    test_port = os.getenv("TEST_PORT", "8002")

    # Start Docker Compose services
    compose_cmd = [
        "docker",
        "compose",
        "-f",
        "docker-compose.yml",
        "-f",
        "docker-compose.test.override.yml",
        "up",
        "-d",
        "--build",
    ]

    try:
        # Start the services
        subprocess.run(compose_cmd, cwd=project_root, check=True)

        # Construct the health check URL
        health_check_url = f"http://localhost:{test_port}/"

        # Wait for the service to be healthy
        _wait_for_service(health_check_url, timeout=120, interval=5)

        # Create a simple object to hold the test port
        class ComposeInfo:
            def __init__(self, test_port):
                self.test_port = test_port

        yield ComposeInfo(test_port)

    finally:
        # Stop and remove Docker Compose services
        stop_cmd = [
            "docker",
            "compose",
            "-f",
            "docker-compose.yml",
            "-f",
            "docker-compose.test.override.yml",
            "down",
        ]
        subprocess.run(stop_cmd, cwd=project_root)


@pytest.fixture(scope="session")
def page_url(app_container) -> str:
    """
    Returns the base URL of the running application.
    """
    test_port = app_container.test_port
    return f"http://localhost:{test_port}/"
