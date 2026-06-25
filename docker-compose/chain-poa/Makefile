SHELL := /bin/bash
.DEFAULT_GOAL := help
MAKEFLAGS += --no-print-directory

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SCRIPTS := $(ROOT)/scripts
COMPOSE := docker compose

.PHONY: help check-deps init
.PHONY: prepare-v1 prepare-v2 prepare-dapps-v4 prepare-traefik
.PHONY: validator-1-up validator-1-down validator-1-logs
.PHONY: validator-2-up validator-2-down validator-2-logs
.PHONY: dapps-v4-up dapps-v4-down dapps-v4-logs
.PHONY: dapps-v5-up dapps-v5-down dapps-v5-logs
.PHONY: enode-testnet enode-mainnet

help: ## Hiển thị danh sách target
	@grep -E '^[a-zA-Z0-9_.-]+:.*##' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-28s\033[0m %s\n", $$1, $$2}'

check-deps: ## Kiểm tra docker và compose
	@command -v docker >/dev/null || (echo "Missing: docker" && exit 1)
	@docker compose version >/dev/null 2>&1 || (echo "Missing: docker compose v2" && exit 1)
	@echo "OK: dependencies satisfied"

init: ## Copy env mẫu (poa.env, validator-1/2.env)
	cp -n envs/poa.env.example envs/poa.env || true
	cp -n envs/validator-1.env.example envs/validator-1.env || true
	cp -n envs/validator-2.env.example envs/validator-2.env || true
	@echo "Edit envs/poa.env and validator envs, then: make prepare-v1"

prepare-v1: ## prepare-envs-validator-1.sh
	$(SCRIPTS)/prepare-envs-validator-1.sh

prepare-v2: ## prepare-envs-validator-2.sh
	$(SCRIPTS)/prepare-envs-validator-2.sh

prepare-dapps-v4: ## v4/prepare-envs-dapps.sh (db, blockscout, faucet, …)
	$(SCRIPTS)/v4/prepare-envs-dapps.sh

prepare-traefik: ## traefik/prepare-envs-traefik.sh (dapps env + Traefik dynamic)
	$(SCRIPTS)/traefik/prepare-envs-traefik.sh

validator-1-up: check-deps ## Up validator-1 stack
	$(COMPOSE) -f compose-validator-1.yml up -d

validator-1-down: ## Down validator-1 stack
	$(COMPOSE) -f compose-validator-1.yml down

validator-1-logs: ## Follow validator-1 logs
	$(COMPOSE) -f compose-validator-1.yml logs -f --tail=100

validator-2-up: check-deps ## Up validator-2 stack
	$(COMPOSE) -f compose-validator-2.yml up -d

validator-2-down: ## Down validator-2 stack
	$(COMPOSE) -f compose-validator-2.yml down

validator-2-logs: ## Follow validator-2 logs
	$(COMPOSE) -f compose-validator-2.yml logs -f --tail=100

dapps-v4-up: check-deps prepare-traefik ## Blockscout v4 + Traefik
	$(COMPOSE) -f compose-dapps-traefik-v4.yml up -d

dapps-v4-down: ## Down Blockscout v4 + Traefik
	$(COMPOSE) -f compose-dapps-traefik-v4.yml down

dapps-v4-logs: ## Follow Blockscout v4 + Traefik logs
	$(COMPOSE) -f compose-dapps-traefik-v4.yml logs -f --tail=100

dapps-v5-up: check-deps prepare-traefik ## Blockscout v5 + Traefik
	$(COMPOSE) -f compose-dapps-traefik-v5.yml up -d

dapps-v5-down: ## Down Blockscout v5 + Traefik
	$(COMPOSE) -f compose-dapps-traefik-v5.yml down

dapps-v5-logs: ## Follow Blockscout v5 + Traefik logs
	$(COMPOSE) -f compose-dapps-traefik-v5.yml logs -f --tail=100

enode-testnet: ## Export enode từ bootnode testnet
	$(SCRIPTS)/get_enode_testnet.sh

enode-mainnet: ## Export enode từ bootnode mainnet
	$(SCRIPTS)/get_enode_mainnet.sh
