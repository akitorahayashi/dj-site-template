# ==============================================================================
# Makefile for Django Project Automation
#
# Provides a unified interface for common development tasks, abstracting away
# the underlying Docker Compose commands for a better Developer Experience (DX).
#
# Inspired by the self-documenting Makefile pattern.
# See: https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
# ==============================================================================

# Default target executed when 'make' is run without arguments
.DEFAULT_GOAL := help

# ==============================================================================
# Sudo Configuration
#
# Allows running Docker commands with sudo when needed (e.g., in CI environments).
# Usage: make up SUDO=true
# ==============================================================================

SUDO_PREFIX :=
ifeq ($(SUDO),true)
	SUDO_PREFIX := sudo
endif

DOCKER_CMD := $(SUDO_PREFIX) docker

-include .env

# Define the project name - try to read from .env file, fallback to directory name
PROJECT_NAME ?= dj-site-template

# Define project names for different environments
DEV_PROJECT_NAME := $(PROJECT_NAME)-dev
PROD_PROJECT_NAME := $(PROJECT_NAME)-prod
TEST_PROJECT_NAME := $(PROJECT_NAME)-test

# ==============================================================================
# Docker Compose Commands
# ==============================================================================

DEV_COMPOSE := $(DOCKER_CMD) compose -f docker-compose.yml -f docker-compose.dev.override.yml --project-name $(DEV_PROJECT_NAME)
PROD_COMPOSE := $(DOCKER_CMD) compose -f docker-compose.yml --project-name $(PROD_PROJECT_NAME)
TEST_COMPOSE := $(DOCKER_CMD) compose -f docker-compose.yml -f docker-compose.test.override.yml --project-name $(TEST_PROJECT_NAME)

# ==============================================================================
# HELP
# ==============================================================================

.PHONY: help
help: ## Show this help message
	@echo "Usage: make [target] [VAR=value]"
	@echo "Options:"
	@echo "  \033[36m%-15s\033[0m %s" "SUDO=true" "Run docker commands with sudo (e.g., make up SUDO=true)"
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ==============================================================================
# Environment Setup
# ==============================================================================

.PHONY: setup
setup: ## Initialize project: install dependencies, create .env file and pull required Docker images
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
	@POSTGRES_IMAGE_NAME="postgres:16-alpine"; \
	if [ -f .env ] && grep -q "^POSTGRES_IMAGE_NAME=" .env; then \
		POSTGRES_IMAGE_NAME=$$(sed -n 's/^POSTGRES_IMAGE_NAME=\(.*\)/\1/p' .env | head -n1 | tr -d '\r'); \
		[ -z "$$POSTGRES_IMAGE_NAME" ] && POSTGRES_IMAGE_NAME="postgres:16-alpine"; \
	fi; \
	echo "Using POSTGRES_IMAGE_NAME=$$POSTGRES_IMAGE_NAME"; \
	$(DOCKER_CMD) pull "$$POSTGRES_IMAGE_NAME"
	@echo "✅ Setup complete. Dependencies are installed and .env file is ready."

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

# ==============================================================================
# CODE QUALITY 
# ==============================================================================

.PHONY: format
format: ## Format code with black and ruff --fix
	@echo "Formatting code with black and ruff..."
	@uv run black .
	@uv run ruff check . --fix

.PHONY: lint
lint: ## Lint code with black check and ruff
	@echo "Linting code with black check and ruff..."
	@uv run black --check .
	@uv run ruff check .

# ==============================================================================
# TESTING
# ==============================================================================

.PHONY: test
test: unit-test build-test e2e-test ## Run the full test suite

.PHONY: unit-test
unit-test: ## Run unit tests
	@echo "Running unit tests..."
	@uv run pytest tests/unit -v -s
	
.PHONY: build-test
build-test: ## Build Docker image to verify build process
	@echo "Building Docker image to verify build process..."
	@$(DOCKER_CMD) build --no-cache --target dev-deps -t test-build:temp . || (echo "Docker build failed"; exit 1)
	@echo "✅ Docker build successful"
	@echo "Cleaning up test image..."
	@$(DOCKER_CMD) rmi test-build:temp || true

.PHONY: e2e-test
e2e-test: ## Run end-to-end tests against a live application stack
	@echo "Running end-to-end tests..."
	@uv run python -m pytest tests/e2e -v -s

# ==============================================================================
# CLEANUP
# ==============================================================================

.PHONY: clean
clean: ## Remove __pycache__ and .venv to make project lightweight
	@echo "🧹 Cleaning up project..."
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@rm -rf .venv
	@rm -rf .pytest_cache
	@rm -rf .ruff_cache
	@echo "✅ Cleanup completed"


