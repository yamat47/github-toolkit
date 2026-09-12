# All targets run inside Docker. Nothing needs to be installed on the host
# except Docker itself.

SHELL := /bin/bash
.DEFAULT_GOAL := help

COMPOSE := docker compose
SKILL_DIRS := $(wildcard skills/*/)
ACTION_FILES := $(wildcard actions/*/action.yml actions/*/action.yaml)

.PHONY: help lint lint-workflows lint-actions lint-skills build

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-16s %s\n", $$1, $$2}'

lint: lint-workflows lint-actions lint-skills ## Run every check

lint-workflows: ## Lint .github/workflows/*.yml with actionlint (also checks inputs of local actions they use)
	$(COMPOSE) run --rm actionlint -color

lint-actions: build ## Validate actions/*/action.yml against the GitHub Actions schema
	@if [ -z "$(ACTION_FILES)" ]; then echo "no actions to validate"; exit 0; fi
	$(COMPOSE) run --rm tooling check-jsonschema --builtin-schema vendor.github-actions $(ACTION_FILES)

lint-skills: build ## Validate every skills/*/SKILL.md against the Agent Skills spec
	@if [ -z "$(SKILL_DIRS)" ]; then echo "no skills to validate"; exit 0; fi
	@for dir in $(SKILL_DIRS); do \
	  echo "validating $$dir"; \
	  $(COMPOSE) run --rm tooling skills-ref validate "$$dir" || exit 1; \
	done

build: ## Build the local tooling image
	$(COMPOSE) build --quiet tooling
