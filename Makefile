SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

VENV ?= venv
NAMESPACE ?= sre-platform
HELM_RELEASE_NAME ?= cloud-native-sre-platform
MONITORING_NAMESPACE ?= monitoring
PROMETHEUS_RELEASE ?= kube-prometheus-stack
LOKI_RELEASE ?= loki
VALUES_FILE ?= deploy/helm/values.yaml
K6_BASE_URL ?= http://localhost:8080/api
MONITORING_ENABLED ?= false

.PHONY: help install clean-venv dev down ps logs logs-api logs-payments build \
	test test-unit test-integration test-all lint helm-deps helm-lint helm-template \
	helm-up-dev helm-test helm-down observability-up deploy terraform-plan validate \
	load-test hpa-scale chaos-latency chaos-error chaos-slow chaos-kill chaos-cleanup \
	evidence destroy clean

help: ## Show available developer, deployment, and evidence commands
	@awk 'BEGIN { FS = ":.*## " } /^[a-zA-Z0-9_-]+:.*## / { printf "%-22s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Create a virtual environment and install application/test dependencies
	python3 -m venv $(VENV)
	$(VENV)/bin/pip install --upgrade pip
	$(VENV)/bin/pip install -r requirements-dev.txt

clean-venv: ## Remove only the project virtual environment
	rm -rf $(VENV)

dev: ## Start the local Compose stack and wait for health checks
	docker compose up -d --wait --wait-timeout 60

down: ## Stop the local Compose stack
	docker compose down

ps: ## Show local Compose service status
	docker compose ps

logs: ## Stream all local Compose logs
	docker compose logs -f

logs-api: ## Stream API logs
	docker compose logs -f api

logs-payments: ## Stream Payments logs
	docker compose logs -f payments

build: ## Build local development images
	docker build -t cloud-native-sre-platform-api:dev -f services/api/Dockerfile .
	docker build -t cloud-native-sre-platform-payments:dev -f services/payments/Dockerfile .

test: test-unit ## Run unit tests without external services

test-unit: ## Run unit tests without external services
	@if [[ -x "$(VENV)/bin/pytest" ]]; then \
		$(VENV)/bin/pytest -v -m "not integration"; \
	else \
		echo "ERROR: run 'make install' first" >&2; exit 2; \
	fi

test-integration: ## Run the API-to-Payments integration suite against Compose
	@if ! curl --fail --silent http://localhost:8000/healthz >/dev/null || \
		! curl --fail --silent http://localhost:8001/healthz >/dev/null; then \
		echo "ERROR: start services with 'make dev' first" >&2; exit 2; \
	fi
	@if [[ -x "$(VENV)/bin/pytest" ]]; then \
		$(VENV)/bin/pytest -v -m integration; \
	else \
		echo "ERROR: run 'make install' first" >&2; exit 2; \
	fi

test-all: ## Run unit tests then Compose integration tests
	$(MAKE) test-unit
	$(MAKE) test-integration

lint: ## Run Ruff over application and test code
	@if [[ -x "$(VENV)/bin/ruff" ]]; then \
		$(VENV)/bin/ruff check services/ tests/; \
	else \
		echo "ERROR: run 'make install' first" >&2; exit 2; \
	fi

helm-deps: ## Build local Helm chart dependencies
	helm dependency build deploy/helm

helm-lint: ## Lint the application Helm chart
	helm lint deploy/helm

helm-template: ## Render the application chart with safe example image coordinates
	helm template $(HELM_RELEASE_NAME) deploy/helm --namespace $(NAMESPACE) \
		--set api.image.repository=example.invalid/api \
		--set api.image.tag=0123456789abcdef \
		--set payments.image.repository=example.invalid/payments \
		--set payments.image.tag=0123456789abcdef

helm-up-dev: helm-deps ## Install local images with development values
	helm upgrade --install $(HELM_RELEASE_NAME) deploy/helm \
		--namespace $(NAMESPACE) --create-namespace --values deploy/helm/values-dev.yaml

helm-test: ## Run the Helm API-flow test hook
	helm test $(HELM_RELEASE_NAME) --namespace $(NAMESPACE)

helm-down: ## Uninstall the application Helm release
	helm uninstall $(HELM_RELEASE_NAME) --namespace $(NAMESPACE)

observability-up: ## Install pinned Prometheus, Grafana, Loki, and Promtail charts
	MONITORING_NAMESPACE="$(MONITORING_NAMESPACE)" \
		PROMETHEUS_RELEASE="$(PROMETHEUS_RELEASE)" LOKI_RELEASE="$(LOKI_RELEASE)" \
		./scripts/deploy-observability.sh

deploy: ## Deploy immutable images; set API/PAYMENTS_IMAGE_REPOSITORY and *_TAG
	NAMESPACE="$(NAMESPACE)" HELM_RELEASE_NAME="$(HELM_RELEASE_NAME)" \
		VALUES_FILE="$(VALUES_FILE)" MONITORING_ENABLED="$(MONITORING_ENABLED)" \
		MONITORING_NAMESPACE="$(MONITORING_NAMESPACE)" \
		PROMETHEUS_RELEASE="$(PROMETHEUS_RELEASE)" ./scripts/deploy.sh

terraform-plan: ## Validate and plan Terraform after copying terraform.tfvars.example
	./scripts/terraform-plan.sh

validate: ## Run read-only live GKE application and observability checks
	NAMESPACE="$(NAMESPACE)" HELM_RELEASE_NAME="$(HELM_RELEASE_NAME)" \
		MONITORING_NAMESPACE="$(MONITORING_NAMESPACE)" \
		PROMETHEUS_RELEASE="$(PROMETHEUS_RELEASE)" LOKI_RELEASE="$(LOKI_RELEASE)" \
		./scripts/validate.sh

load-test: ## Run the baseline k6 test against K6_BASE_URL
	K6_BASE_URL="$(K6_BASE_URL)" ./scripts/load-test.sh baseline

hpa-scale: ## Run the HPA k6 load generator; capture before/during/after separately
	K6_BASE_URL="$(K6_BASE_URL)" ./scripts/load-test.sh hpa-scale

chaos-latency: ## Inject reversible Payments latency
	NAMESPACE="$(NAMESPACE)" HELM_RELEASE_NAME="$(HELM_RELEASE_NAME)" ./scripts/fault-inject.sh latency

chaos-error: ## Inject reversible Payments HTTP 500 failures
	NAMESPACE="$(NAMESPACE)" HELM_RELEASE_NAME="$(HELM_RELEASE_NAME)" ./scripts/fault-inject.sh failure

chaos-slow: ## Inject reversible Payments slow responses
	NAMESPACE="$(NAMESPACE)" HELM_RELEASE_NAME="$(HELM_RELEASE_NAME)" ./scripts/fault-inject.sh slow

chaos-kill: ## Delete one Payments pod to test recovery, not PDB eviction
	NAMESPACE="$(NAMESPACE)" HELM_RELEASE_NAME="$(HELM_RELEASE_NAME)" ./scripts/fault-inject.sh kill

chaos-cleanup: ## Remove injected fault state and reconcile the workload
	NAMESPACE="$(NAMESPACE)" HELM_RELEASE_NAME="$(HELM_RELEASE_NAME)" ./scripts/fault-inject.sh cleanup

evidence: ## Capture non-sensitive live cluster, HPA, Envoy, and SLO evidence
	NAMESPACE="$(NAMESPACE)" HELM_RELEASE_NAME="$(HELM_RELEASE_NAME)" \
		MONITORING_NAMESPACE="$(MONITORING_NAMESPACE)" \
		PROMETHEUS_RELEASE="$(PROMETHEUS_RELEASE)" ./scripts/evidence/capture-all.sh

destroy: ## Destroy Terraform-managed dev infrastructure; require CONFIRM_DESTROY=yes
	CONFIRM_DESTROY="$(CONFIRM_DESTROY)" ./scripts/destroy.sh

clean: ## Stop local Compose containers and remove its project volumes
	docker compose down -v --remove-orphans
