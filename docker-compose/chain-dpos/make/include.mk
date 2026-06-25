# Shared conventions for chain-dpos Makefile.
# Override from CLI: make deploy WITH_TRAEFIK=1 SERVER=user@host

SHELL := /bin/bash
.DEFAULT_GOAL := help
MAKEFLAGS += --no-print-directory

COMPOSE := docker compose

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
SCRIPTS := $(ROOT)/scripts

SERVER ?=
_REMOTE_FROM_DEPLOY_ENV := $(shell \
	grep -E '^[[:space:]]*REMOTE_DEPLOY_DIR=' '$(ROOT)/envs/deploy.env' 2>/dev/null | \
	tail -1 | cut -d= -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$$//;s/^"//;s/"$$//;s/^'\''//;s/'\''$$//')
REMOTE_DIR ?= $(if $(_REMOTE_FROM_DEPLOY_ENV),$(_REMOTE_FROM_DEPLOY_ENV),/opt/blockchain-dock)
DOCKERHUB_NAMESPACE ?=

WITH_TRAEFIK ?= 0
CHAIN_ONLY ?= 0
DAPPS_ONLY ?= 0
SKIP_HEALTH ?= 0
SKIP_GENESIS ?= 0
CONFIRM ?= 0

.PHONY: help check-deps
help: ## Hiển thị danh sách target
	@grep -hE '^[a-zA-Z0-9_.-]+:.*##' $(MAKEFILE_LIST) | \
		sort -u | \
		awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-28s\033[0m %s\n", $$1, $$2}'

check-deps: ## Kiểm tra docker, compose, jq, node
	@command -v docker >/dev/null || (echo "Missing: docker" && exit 1)
	@docker compose version >/dev/null 2>&1 || (echo "Missing: docker compose v2" && exit 1)
	@command -v jq >/dev/null || (echo "Missing: jq" && exit 1)
	@command -v node >/dev/null || (echo "Missing: node 18+" && exit 1)
	@echo "OK: dependencies satisfied"
