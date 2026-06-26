# Shared conventions for chain-dpos Makefile.
# Override from CLI: make deploy WITH_TRAEFIK=1 SERVER=user@host

SHELL := /bin/bash
.DEFAULT_GOAL := help
MAKEFLAGS += --no-print-directory

COMPOSE := docker compose

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
SCRIPTS := $(ROOT)/scripts

# Read VAR=value from envs/deploy.env (last match wins; strips quotes)
_deploy_env_get = $(shell \
	grep -E '^[[:space:]]*$(1)=' '$(ROOT)/envs/deploy.env' 2>/dev/null | \
	tail -1 | cut -d= -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$$//;s/^"//;s/"$$//;s/^'\''//;s/'\''$$//')

EXPLORER_SERVER ?= $(call _deploy_env_get,EXPLORER_SERVER)
SEED_SERVER ?= $(call _deploy_env_get,SEED_SERVER)
DAPPS_SERVER ?= $(call _deploy_env_get,DAPPS_SERVER)
SERVER ?=
EXPLORER ?= 0
SEED ?= 0
DAPPS ?= 0

# Generic SSH: SERVER (CLI) > EXPLORER=1 | SEED=1 | DAPPS=1 → host trong deploy.env
_ssh_from_flags = $(or \
	$(if $(filter 1 true,$(EXPLORER)),$(EXPLORER_SERVER)), \
	$(if $(filter 1 true,$(SEED)),$(SEED_SERVER)), \
	$(if $(filter 1 true,$(DAPPS)),$(DAPPS_SERVER)))
SSH_TARGET := $(or $(SERVER),$(_ssh_from_flags))

# Target theo vai trò (không cần cờ — tên target đã rõ server)
EXPLORER_TARGET := $(or $(SERVER),$(EXPLORER_SERVER))
SEED_TARGET := $(or $(SERVER),$(SEED_SERVER))
DAPPS_TARGET := $(or $(SERVER),$(DAPPS_SERVER))

REMOTE_DIR ?= $(or $(call _deploy_env_get,REMOTE_DEPLOY_DIR),/opt/blockchain-dock)

# Thông báo lỗi chung cho lệnh đa server
_ssh_usage_hint = SERVER=user@host | EXPLORER=1 | SEED=1 | DAPPS=1 (set *_SERVER in envs/deploy.env)
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
