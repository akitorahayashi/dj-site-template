# ==============================================================================
# justfile for Django Project Automation
# ==============================================================================

set dotenv-load

PROJECT_NAME := env("PROJECT_NAME", "dj-site-template")
POSTGRES_IMAGE := env("POSTGRES_IMAGE", "postgres:16-alpine")

DEV_PROJECT_NAME := PROJECT_NAME + "-dev"
PROD_PROJECT_NAME := PROJECT_NAME + "-prod"
TEST_PROJECT_NAME := PROJECT_NAME + "-test"

DEV_COMPOSE  := "docker compose -f docker-compose.yml -f docker-compose.dev.override.yml --project-name " + DEV_PROJECT_NAME
PROD_COMPOSE := "docker compose -f docker-compose.yml --project-name " + PROD_PROJECT_NAME
TEST_COMPOSE := "docker compose -f docker-compose.yml -f docker-compose.test.override.yml --project-name " + TEST_PROJECT_NAME

# default recipe
default: help

# Show available recipes
help:
    @echo "Usage: just [recipe]"
    @echo "Available recipes:"
    @just --list | tail -n +2 | awk '{printf "  \033[36m%-20s\033[0m %s\n", $1, substr($0, index($0, $2))}'

# ==============================================================================
# Environment Setup
# ==============================================================================

# Initialize project: install dependencies, create .env file and pull required Docker images
setup:
    @echo "Installing python dependencies with uv..."
    @uv sync
    @echo "Creating environment file..."
    @if [ ! -f .env ] && [ -f .env.example ]; then \
        echo "Creating .env from .env.example..."; \
        cp .env.example .env; \
        echo "✅ Environment file created (.env)"; \
    else \
        echo ".env already exists. Skipping creation."; \
    fi
    @echo "💡 You can customize .env for your specific needs:"
    @echo "   📝 Change database settings if needed"
    @echo "   📝 Adjust other settings as needed"
    @echo ""
    @echo "Pulling PostgreSQL image for development..."
    docker pull {{POSTGRES_IMAGE}}
    @echo "✅ Setup complete. Dependencies are installed and .env file is ready."

# ==============================================================================
# Development Environment Commands
# ==============================================================================

# Build images and start dev containers
up:
    @echo "Building images and starting DEV containers..."
    @{{DEV_COMPOSE}} up --build -d

# Stop dev containers
down:
    @echo "Stopping DEV containers..."
    @{{DEV_COMPOSE}} down --remove-orphans

# Build images and start prod-like containers
up-prod:
    @echo "Starting up PROD-like containers..."
    @{{PROD_COMPOSE}} up -d --build

# Stop prod-like containers
down-prod:
    @echo "Shutting down PROD-like containers..."
    @{{PROD_COMPOSE}} down --remove-orphans

# Rebuild services, pulling base images, without cache, and restart
rebuild:
    @echo "Rebuilding all DEV services with --no-cache and --pull..."
    @{{DEV_COMPOSE}} up -d --build --no-cache --pull always

# ==============================================================================
# CODE QUALITY
# ==============================================================================

# Format code with black and ruff --fix
format:
    @echo "Formatting code with black and ruff..."
    @uv run black .
    @uv run ruff check . --fix

# Lint code with black check and ruff
lint:
    @echo "Linting code with black and ruff..."
    @uv run black --check .
    @uv run ruff check .

# ==============================================================================
# TESTING
# ==============================================================================

# Run complete test suite (local then docker)
@test: local-test docker-test

# Run lightweight local test suite (recommended for development)
@local-test: unit-test sqlt-test intg-test

# Run unit tests
unit-test:
    @echo "Running unit tests..."
    @uv run pytest tests/unit -v -s

# Run database tests with SQLite (fast, lightweight)
sqlt-test:
    @echo "🚀 Running database tests with SQLite..."
    @USE_SQLITE=true uv run pytest tests/db -v -s

# Run integration tests using Django runserver (lightweight, no containers)
intg-test:
    @echo "🚀 Running integration tests with Django runserver..."
    @uv run pytest tests/intg -v -s

# Run all Docker-based tests
docker-test: build-test pstg-test e2e-test

# Build Docker image to verify build process
build-test:
    @echo "Building Docker image to verify build process..."
    docker build --no-cache --target production -t test-build:temp . || (echo "Docker build failed"; exit 1)
    @echo "✅ Docker build successful"
    @echo "Cleaning up test image..."
    -docker rmi test-build:temp 2>/dev/null || true

# Run database tests with PostgreSQL (robust, production-like)
pstg-test:
    @echo "🚀 Starting TEST containers for database test..."
    @USE_SQLITE=false {{TEST_COMPOSE}} up -d --build
    @echo "Running database tests..."
    -USE_SQLITE=false {{TEST_COMPOSE}} exec web pytest tests/db -v -s
    @echo "🔴 Stopping TEST containers..."
    @USE_SQLITE=false {{TEST_COMPOSE}} down

# Run e2e tests against containerized application stack
e2e-test:
    @echo "🚀 Running e2e tests..."
    @uv run pytest tests/e2e -v -s

# ==============================================================================
# CLEANUP
# ==============================================================================

# Remove __pycache__ and .venv to make project lightweight
clean:
    @echo "🧹 Cleaning up project..."
    @find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    @rm -rf .venv
    @rm -rf .pytest_cache
    @rm -rf .ruff_cache
    @echo "✅ Cleanup completed"