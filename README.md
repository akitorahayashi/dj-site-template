# Django Project Template

This is a comprehensive Django project template designed to be a starting point for various web applications.

## Prerequisites

Before you begin, ensure you have the following tools installed:

- **Docker**: Latest version recommended
- **Docker Compose**: Included with Docker
- **just**: Command runner, install from https://github.com/casey/just
- **Python**: 3.12 (recommended, see `.python-version`)
- **uv**: Latest version recommended (for local development)

## Getting Started

To start your new project, clone this repository. Then, to set up the local environment and install dependencies using uv, run:

```bash
just setup
```
This command will also create the necessary `.env` files from the example file.

## Building and Running with Docker

The application is designed to run inside Docker containers. To build and start the containers in the background, use:

```bash
just up
```

Once the containers are running, you can access the application at `http://localhost:8000`.

To stop and remove the containers, run:
```bash
just down
```

### Production-like Execution

To simulate a production environment, you can use a command that starts the containers without the development-specific overrides:

```bash
just up-prod
```

> **⚠️ Important**
> Before running `just up-prod`, you must run `just setup` and configure the production-specific environment variables. The `.env` file is ignored by Git.

To stop and remove the production-like containers:
```bash
just down-prod
```

## Testing and Code Quality

The project is equipped with tools to maintain code quality, including tests, a linter, and a formatter.

### Running Tests

**Local development (fast, lightweight):**
```bash
just test
```
Runs unit tests, SQLite database tests, and integration tests using Django runserver.

**Production-like testing (comprehensive):**
```bash
just docker-test
```
Runs Docker build verification, PostgreSQL database tests, and end-to-end tests in containers.

### Code Formatting and Linting

We use `black` and `ruff` to automatically format the code.

To format your code:
```bash
just format
```

To check for linting and formatting issues (as the CI pipeline does):
```bash
just lint
```

## Project Structure

A key feature of this template is how Django apps are organized.

-   **`apps/` directory**: All Django applications reside within the `apps/` directory.
-   **Namespace Package**: The `apps/` directory is configured as a [PEP 420 namespace package](https://www.python.org/dev/peps/pep-0420/), meaning it does **not** contain an `__init__.py` file. This allows for better separation of concerns and makes it easier to add or remove apps.
-   **Packaging**: The `pyproject.toml` file is configured to include the entire `apps` directory in the distribution.

## Environment Variables

The following environment variables can be configured in your `.env` file:

### Project Settings
- `PROJECT_NAME`: Name of the project (default: `dj-site-template`)

### Web Server Settings
- `HOST_BIND_IP`: IP address to bind the server to (default: `127.0.0.1`)
- `HOST_PORT`: Port for production server (default: `8000`)
- `DEV_PORT`: Port for development server (default: `8001`)
- `TEST_PORT`: Port for test server (default: `8002`)

### Django Configuration
- `DEBUG`: Enable debug mode (default: `True`)
- `ALLOWED_HOSTS`: Comma-separated list of allowed hosts (default: `localhost,127.0.0.1`)
- `SECRET_KEY`: Secret key for Django (required in production)
- `DJANGO_SETTINGS_MODULE`: Django settings module (default: `config.settings`)
- `DATABASE_CONN_MAX_AGE`: Database connection max age (default: `0`)

### Database Settings
- `USE_SQLITE`: Use SQLite database (default: `true`)
- `POSTGRES_IMAGE_NAME`: PostgreSQL Docker image (default: `postgres:16-alpine`)
- `POSTGRES_USER`: PostgreSQL username (default: `dj-site-user`)
- `POSTGRES_PASSWORD`: PostgreSQL password (default: `dj-site-password`)
- `POSTGRES_HOST`: PostgreSQL host (default: `db`)
- `POSTGRES_PORT`: PostgreSQL port (default: `5432`)
- `POSTGRES_HOST_DB`: Production PostgreSQL database name (default: `dj-site-template`)
- `POSTGRES_DEV_DB`: Development PostgreSQL database name (default: `dj-site-template-dev`)
- `POSTGRES_TEST_DB`: Test PostgreSQL database name (default: `dj-site-template-test`)

