SHELL := /bin/bash
.DEFAULT_GOAL := help
MAKEFLAGS += --no-print-directory

REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BASE := $(abspath $(REPO_ROOT)/../blockchain-docker-base)
DPOS := $(REPO_ROOT)/docker-compose/chain-dpos
POA := $(REPO_ROOT)/docker-compose/chain-poa

BUILD_TARGETS := $(filter-out build,$(MAKECMDGOALS))
DPOS_TARGETS := $(filter-out dpos,$(MAKECMDGOALS))
POA_TARGETS := $(filter-out poa,$(MAKECMDGOALS))

.PHONY: help check build dpos poa

help: ## Entry point — liệt kê nhóm lệnh
	@echo "blockchain-dockerize Makefile"
	@echo ""
	@echo "  make build [target]     → sibling blockchain-docker-base (build-chain, push, …)"
	@echo "  make dpos [target]      → chain-dpos (deploy, sync, …)"
	@echo "  make poa [target]       → chain-poa (validator, dapps v4/v5, …)"
	@echo "  make check              → kiểm tra deps tại chain-dpos"
	@echo ""
	@echo "Ví dụ:"
	@echo "  make dpos deploy WITH_TRAEFIK=1"
	@echo "  make build build-chain"
	@echo ""
	@echo "Chi tiết: docs/makefile.md"

check: ## Kiểm tra docker, compose, jq, node (chain-dpos)
	$(MAKE) -C $(DPOS) check-deps

build: ## Delegate to blockchain-docker-base (default: build all images)
	@test -f "$(BASE)/Makefile" || (echo "Missing $(BASE)/Makefile — clone blockchain-docker-base next to this repo." && exit 1)
	$(MAKE) -C $(BASE) $(if $(BUILD_TARGETS),$(BUILD_TARGETS),build)

dpos: ## Delegate to chain-dpos (default: help)
	$(MAKE) -C $(DPOS) $(if $(DPOS_TARGETS),$(DPOS_TARGETS),help)

poa: ## Delegate to chain-poa (default: help)
	$(MAKE) -C $(POA) $(if $(POA_TARGETS),$(POA_TARGETS),help)

%:
	@:
