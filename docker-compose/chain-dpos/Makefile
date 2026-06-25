include make/include.mk

.PHONY: init render genesis bootstrap deploy deploy-chain deploy-dapps
.PHONY: health verify enode patch-spec validator-restart
.PHONY: validator-up validator-down validator-logs
.PHONY: dapps-up dapps-down dapps-logs
.PHONY: prepare-remote sync provision-remote deploy-remote-validator deploy-remote-dapps
.PHONY: ssh-deploy-validator ssh-deploy-dapps gtbs-prepare

init: ## Copy env mẫu (deploy.env, dpos.chain.env, dpos.contract.env)
	cp -n envs/deploy.env.example envs/deploy.env || true
	cp -n envs/dpos.chain.env.example envs/dpos.chain.env || true
	cp -n envs/dpos.contract.env.example envs/dpos.contract.env || true
	@echo "Edit envs/deploy.env then: make render"

render: check-deps ## Render tất cả *.env từ deploy.env
	$(SCRIPTS)/render-envs.sh envs/deploy.env $(if $(filter 1,$(WITH_TRAEFIK)),--with-traefik,)

genesis: check-deps ## Phase A: prepare-genesis.sh
	$(SCRIPTS)/prepare-genesis.sh

bootstrap: check-deps render ## Phase A–F: bootstrap-chain.sh
	$(SCRIPTS)/bootstrap-chain.sh $(if $(filter 1,$(SKIP_GENESIS)),--skip-genesis,)

deploy: check-deps ## Full local deploy (deploy-all.sh)
	$(SCRIPTS)/deploy-all.sh \
		$(if $(filter 1,$(CHAIN_ONLY)),--chain-only,) \
		$(if $(filter 1,$(DAPPS_ONLY)),--dapps-only,) \
		$(if $(filter 1,$(WITH_TRAEFIK)),--with-traefik,) \
		$(if $(filter 1,$(SKIP_HEALTH)),--skip-health,)

deploy-chain: ## Chỉ chain (validator bootstrap)
	$(MAKE) deploy CHAIN_ONLY=1

deploy-dapps: ## Chỉ DApps (chain đã chạy)
	$(MAKE) deploy DAPPS_ONLY=1 WITH_TRAEFIK=1

health: ## Chạy health-check.sh
	$(SCRIPTS)/health-check.sh

verify: ## Phase E: verify-contracts-transition.sh
	$(SCRIPTS)/verify-contracts-transition.sh

enode: ## Phase F: get_enode.sh
	$(SCRIPTS)/get_enode.sh

patch-spec: ## Phase D: patch-spec-after-deploy.sh
	$(SCRIPTS)/patch-spec-after-deploy.sh

validator-restart: ## Restart validator-1 sau patch spec
	$(SCRIPTS)/restart-validator-1.sh

validator-up: ## docker compose up validator-1 (+ consensus profile)
	$(COMPOSE) -f compose-validator-1.yml --profile consensus up -d

validator-down: ## docker compose down validator stack
	$(COMPOSE) -f compose-validator-1.yml down

validator-logs: ## Follow logs validator-1
	$(COMPOSE) -f compose-validator-1.yml logs -f --tail=100

dapps-up: ## Up DApps v11 (+ faucet nếu testnet)
	@set -a && source envs/dpos.chain.env && set +a; \
	PROFILES=""; \
	[ "$$NETWORK_TYPE" = testnet ] && PROFILES="--profile faucet"; \
	$(COMPOSE) -f compose-dapps-traefik-v11.yml $$PROFILES up -d

dapps-down: ## Down DApps stack
	$(COMPOSE) -f compose-dapps-traefik-v11.yml down

dapps-logs: ## Follow DApps logs
	$(COMPOSE) -f compose-dapps-traefik-v11.yml logs -f --tail=100

prepare-remote: check-deps ## Local: prepare-deploy.sh
	$(SCRIPTS)/local/prepare-deploy.sh $(if $(filter 1,$(WITH_TRAEFIK)),--with-traefik,)

sync: ## Local: rsync bundle lên server (SERVER bắt buộc)
	@test -n "$(SERVER)" || (echo "Usage: make sync SERVER=user@host [REMOTE_DIR=...]" && exit 1)
	$(SCRIPTS)/local/sync-to-server.sh "$(SERVER)" "$(REMOTE_DIR)"

provision-remote: ## Local: provision Docker trên server
	@test -n "$(SERVER)" || (echo "Usage: make provision-remote SERVER=user@host" && exit 1)
	$(SCRIPTS)/local/provision-remote.sh "$(SERVER)"

deploy-remote-validator: ## Server: deploy-validator.sh
	$(SCRIPTS)/remote/deploy-validator.sh $(if $(filter 1,$(WITH_TRAEFIK)),--with-traefik,)

deploy-remote-dapps: ## Server: deploy-dapps.sh
	$(SCRIPTS)/remote/deploy-dapps.sh

ssh-deploy-validator: ## Chạy deploy-validator trên server qua SSH
	@test -n "$(SERVER)" || (echo "Usage: make ssh-deploy-validator SERVER=user@host" && exit 1)
	ssh "$(SERVER)" "cd $(REMOTE_DIR)/blockchain-dockerize/docker-compose/chain-dpos && ./scripts/remote/deploy-validator.sh $(if $(filter 1,$(WITH_TRAEFIK)),--with-traefik,)"

ssh-deploy-dapps: ## Chạy deploy-dapps trên server qua SSH
	@test -n "$(SERVER)" || (echo "Usage: make ssh-deploy-dapps SERVER=user@host" && exit 1)
	ssh "$(SERVER)" "cd $(REMOTE_DIR)/blockchain-dockerize/docker-compose/chain-dpos && ./scripts/remote/deploy-dapps.sh"

gtbs-prepare: ## Chuẩn bị deploy GTBS (ENABLE_CUSTOM_STAKING=true trong deploy.env)
	@grep -q 'ENABLE_CUSTOM_STAKING=true' envs/deploy.env || \
		(echo "Set ENABLE_CUSTOM_STAKING=true in envs/deploy.env" && exit 1)
	$(MAKE) prepare-remote WITH_TRAEFIK=$(WITH_TRAEFIK)
