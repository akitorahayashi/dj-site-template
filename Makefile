.DEFAULT_GOAL := help

# ==============================================================================
# Variables
# ==============================================================================

# Sudo Configuration - Allows running Docker commands with sudo when needed
SUDO_PREFIX :=
ifeq ($(SUDO),true)
	SUDO_PREFIX := sudo
endif

DOCKER_CMD := $(SUDO_PREFIX) docker

# ==============================================================================
# Docker Commands
# ==============================================================================

DEV_COMPOSE := $(DOCKER_CMD) compose -f docker-compose.yml -f docker-compose.dev.override.yml
PROD_COMPOSE := $(DOCKER_CMD) compose -f docker-compose.yml  
TEST_COMPOSE := $(DOCKER_CMD) compose -f docker-compose.yml -f docker-compose.test.override.yml

# ==============================================================================
# Help
# ==============================================================================

.PHONY: all
all: help ## Default target

.PHONY: help
help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "; OFS=" "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ==============================================================================
# Environment Setup
# ==============================================================================

.PHONY: setup
setup: ## Install dependencies and create .env file from .env.example
	@echo "🐍 Installing python dependencies with uv..."
	@uv sync
	@echo "Creating .env file..."
	@if [ ! -f .env ] && [ -f .env.example ]; then \
		echo "Creating .env from .env.example..."; \
		cp .env.example .env; \
	else \
		echo ".env already exists. Skipping creation."; \
	fi
	@echo "Setup complete. Dependencies are installed and .env file is ready."

# ==============================================================================
# Development Environment Commands
# ==============================================================================

.PHONY: up
up: ## Build images and start dev containers
	@echo "Building images and starting DEV containers..."
	@$(DEV_COMPOSE) up --build -d

.PHONY: down
down: ## Stop dev containers
	@echo "Stopping DEV containers..."
	@$(DEV_COMPOSE) down --remove-orphans

.PHONY: up-prod
up-prod: ## Build images and start prod-like containers
	@echo "Starting up PROD-like containers..."
	@$(PROD_COMPOSE) up -d --build

.PHONY: down-prod
down-prod: ## Stop prod-like containers
	@echo "Shutting down PROD-like containers..."
	@$(PROD_COMPOSE) down --remove-orphans

.PHONY: rebuild
rebuild: ## Rebuild services, pulling base images, without cache, and restart
	@echo "Rebuilding all DEV services with --no-cache and --pull..."
	@$(DEV_COMPOSE) up -d --build --no-cache --pull always

.PHONY: clean
clean: ## Remove all generated files and stop all containers
	@echo "Cleaning up project..."
	@$(DEV_COMPOSE) down -v --remove-orphans
	@$(PROD_COMPOSE) down -v --remove-orphans
	@echo "Cleanup complete."

.PHONY: logs
logs: ## Show and follow dev container logs
	@echo "Showing DEV logs..."
	@$(DEV_COMPOSE) logs -f

.PHONY: shell
shell: ## Start a shell inside the dev 'web' container
	@$(DEV_COMPOSE) ps --status=running --services | grep -q '^web$$' || { echo "Error: web container is not running. Please run 'make up' first." >&2; exit 1; }
	@echo "Connecting to DEV 'web' container shell..."
	@$(DEV_COMPOSE) exec web /bin/bash

# ==============================================================================
# Django Management Commands
# ==============================================================================

.PHONY: makemigrations
makemigrations: ## [DEV] Create new migration files
	@$(DEV_COMPOSE) exec web python manage.py makemigrations

.PHONY: migrate
migrate: ## [DEV] Run database migrations
	@echo "Running DEV database migrations..."
	@$(DEV_COMPOSE) exec web python manage.py migrate

.PHONY: superuser
superuser: ## [DEV] Create a Django superuser
	@echo "Creating DEV superuser..."
	@$(DEV_COMPOSE) exec web python manage.py createsuperuser

.PHONY: migrate-prod
migrate-prod: ## [PROD] Run database migrations in production-like environment
	@echo "Running PROD-like database migrations..."
	@$(PROD_COMPOSE) exec web python manage.py migrate

.PHONY: superuser-prod
superuser-prod: ## [PROD] Create a Django superuser in production-like environment
	@echo "Creating PROD-like superuser..."
	@$(PROD_COMPOSE) exec web python manage.py createsuperuser

# ==============================================================================
#  Code Quality
# ==============================================================================

.PHONY: format
format: ## Format code with Black and fix Ruff issues
	@echo "Formatting code with Black and Ruff..."
	@black .
	@ruff check . --fix

.PHONY: lint
lint: ## Check code format and lint issues
	@echo "Checking code format with Black..."
	@black --check .
	@echo "Checking code with Ruff..."
	@ruff check .

# ==============================================================================
#  Testing
# ==============================================================================

.PHONY: test
test: unit-test build-test db-test e2e-test ## Run the full test suite

.PHONY: unit-test
unit-test: ## Run unit tests
	@echo "Running unit tests..."
	@pytest tests/unit -v -s

.PHONY: db-test
db-test: ## Run the slower, database-dependent tests locally
	@echo "Running database tests..."
	@python -m pytest tests/db -v -s
	
.PHONY: build-test
build-test: ## Build Docker image and run smoke tests in clean environment
	@echo "Building Docker image and running smoke tests..."
	@$(DOCKER_CMD) build --target dev-deps -t test-build:temp . || (echo "Docker build failed"; exit 1)
	@echo "Running smoke tests in Docker container..."
	@$(DOCKER_CMD) run --rm \
		--env-file .env \
		-v $(CURDIR)/tests:/app/tests \
		-v $(CURDIR)/apps:/app/apps \
		-v $(CURDIR)/config:/app/config \
		-v $(CURDIR)/manage.py:/app/manage.py \
		-v $(CURDIR)/pyproject.toml:/app/pyproject.toml \
		-e PATH="/app/.venv/bin:$$PATH" \
		test-build:temp \
		sh -c "/app/.venv/bin/python -m pytest tests/unit/" || (echo "Smoke tests failed"; exit 1)
	@echo "Cleaning up test image..."
	@$(DOCKER_CMD) rmi test-build:temp || true

.PHONY: e2e-test
e2e-test: ## Run end-to-end tests against a live application stack
	@echo "Running end-to-end tests..."
	@python -m pytest tests/e2e -v -s




