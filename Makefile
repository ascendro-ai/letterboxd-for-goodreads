PYTHON ?= python3.11
ROOT := $(shell pwd)

.PHONY: help setup run test test-backend test-pipeline migrate seed docker-up docker-down docker-reset clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

setup: docker-up _venvs _envs migrate seed ## Full local setup (Postgres + venvs + deps + migrate + seed)
	@echo ""
	@echo "Setup complete! Run 'make run' to start the server."

docker-up: ## Start Postgres container
	docker compose up -d --wait

docker-down: ## Stop Postgres container
	docker compose down

docker-reset: ## Stop Postgres and delete all data
	docker compose down -v

_venvs:
	@echo "Setting up backend venv..."
	@test -d backend/.venv || $(PYTHON) -m venv backend/.venv
	@backend/.venv/bin/pip install -q -r backend/requirements.txt
	@echo "Setting up pipeline venv..."
	@test -d pipeline/.venv || $(PYTHON) -m venv pipeline/.venv
	@pipeline/.venv/bin/pip install -q -r pipeline/requirements.txt

_envs:
	@test -f backend/.env || (cp backend/.env.example backend/.env && echo "Created backend/.env")
	@test -f pipeline/.env || (cp pipeline/.env.example pipeline/.env && echo "Created pipeline/.env")

run: ## Start FastAPI dev server on :8000
	PYTHONPATH=$(ROOT) backend/.venv/bin/uvicorn backend.api.main:app --reload --port 8000

migrate: ## Run Alembic migrations
	cd backend && .venv/bin/alembic upgrade head

seed: ## Insert dev seed data
	backend/.venv/bin/python scripts/seed.py

test: test-backend test-pipeline ## Run all tests

test-backend: ## Run backend tests
	PYTHONPATH=$(ROOT) backend/.venv/bin/pytest backend/tests/ -v

test-pipeline: ## Run pipeline tests
	cd pipeline && .venv/bin/pytest tests/ -v

clean: ## Remove venvs (preserves .env and Docker volumes)
	rm -rf backend/.venv pipeline/.venv
