import os
import subprocess
import time
import socket
from pathlib import Path

import pytest
import httpx


def _find_free_port() -> int:
    """Find a free port to use for the test server."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(('', 0))
        s.listen(1)
        port = s.getsockname()[1]
    return port


def _is_service_ready(url: str, expected_status: int = 200) -> bool:
    """Check if HTTP service is ready by making a request."""
    try:
        with httpx.Client(timeout=5) as client:
            response = client.get(url)
        return response.status_code == expected_status
    except Exception:
        return False


def _wait_for_service(url: str, timeout: int = 30, interval: int = 1) -> None:
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
def test_server():
    """
    Provides a Django development server using manage.py runserver.
    """
    # Find the project root
    project_root = Path(__file__).parent.parent.parent

    # Find a free port
    port = _find_free_port()

    # Start Django runserver
    runserver_cmd = [
        "uv", "run", "python", "manage.py", "runserver", f"127.0.0.1:{port}", "--noreload"
    ]

    try:
        # Start the runserver process
        process = subprocess.Popen(
            runserver_cmd,
            cwd=project_root,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )

        # Construct the health check URL
        base_url = f"http://127.0.0.1:{port}"

        # Wait for the service to be ready
        _wait_for_service(base_url, timeout=30, interval=1)

        # Create a simple object to hold the port and process
        class ServerInfo:
            def __init__(self, port, process):
                self.port = port
                self.process = process

        yield ServerInfo(port, process)

    finally:
        # Stop the runserver process
        if 'process' in locals():
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()


@pytest.fixture(scope="session")
def page_url(test_server) -> str:
    """
    Returns the base URL of the running Django development server.
    """
    return f"http://127.0.0.1:{test_server.port}/"