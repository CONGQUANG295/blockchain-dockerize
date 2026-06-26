include make/include.mk

.PHONY: init render genesis bootstrap deploy deploy-chain deploy-dapps
.PHONY: health verify enode patch-spec validator-restart
.PHONY: validator-up validator-down validator-logs stop-validator-nodes
.PHONY: dapps-up dapps-down dapps-logs
.PHONY: prepare-remote sync provision-remote setup-ssh install-make-remote deploy-remote-validator deploy-remote-dapps deploy-remote-explorer
.PHONY: export-peer-config prepare-new-node pull-peer-config sync-peer-bundle
.PHONY: prepare-new-validator-local sync-new-validator
.PHONY: ssh-new-validator-prepare ssh-new-validator-up ssh-new-validator-down ssh-new-validator-logs
.PHONY: validator-2-prepare-local sync-validator-2 prepare-validator-2 pull-validator-1-enode
.PHONY: open-p2p-port ssh-open-p2p-port
.PHONY: ssh-deploy-validator ssh-stop-validator-nodes ssh-install-make ssh-deploy-dapps ssh-deploy-explorer gtbs-prepare

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

enode: ## Refresh enode + reserved-peers (export-peer-config.sh)
	$(SCRIPTS)/export-peer-config.sh

export-peer-config: ## Seed validator: spec + enode → genesis/reserved-peers.txt
	$(SCRIPTS)/export-peer-config.sh

prepare-new-node: check-deps ## Chuẩn bị RPC hoặc validator mới (tự tạo keystore + address)
	@test -n "$(TYPE)" || (echo "Usage: make prepare-new-node TYPE=rpc|validator [NODE_ID=name] [FORCE_KEYS=1]" && exit 1)
	$(SCRIPTS)/prepare-new-node.sh --type "$(TYPE)" \
		$(if $(NODE_ID),--node-id "$(NODE_ID)",) \
		$(if $(filter 1,$(FORCE_KEYS)),--force-keys,)

pull-peer-config: ## Local: kéo peer bundle từ seed validator server (một lần sau seed deploy)
	@test -n "$(SEED_TARGET)" || (echo "Usage: make pull-peer-config [SERVER=user@host] — or set SEED_SERVER in envs/deploy.env" && exit 1)
	$(SCRIPTS)/local/pull-peer-config.sh "$(SEED_TARGET)" "$(REMOTE_DIR)" \
		$(if $(filter 1,$(SKIP_REFRESH)),--skip-refresh,)

sync-peer-bundle: ## Local: đẩy peer bundle lên server non-seed (EXPLORER=1 hoặc SERVER=)
	@test -n "$(SSH_TARGET)" || (echo "Usage: make sync-peer-bundle $(_ssh_usage_hint)" && exit 1)
	$(SCRIPTS)/local/sync-peer-bundle.sh "$(SSH_TARGET)" "$(REMOTE_DIR)" \
		$(if $(filter 1,$(DRY_RUN)),--dry-run,)

prepare-new-validator-local: check-deps ## Local: tạo node validator mới (pull bundle nếu thiếu)
	@if [ "$(SKIP_PULL)" = "1" ]; then \
	  echo "SKIP_PULL=1 — using local peer bundle"; \
	elif [ -f genesis/reserved-peers.txt ] && [ -f genesis/spec.json ]; then \
	  echo "Local peer bundle found — skipping pull-peer-config"; \
	else \
	  test -n "$(SEED_SERVER)" || (echo "Usage: make prepare-new-validator-local [SEED_SERVER=user@seed] — or set SEED_SERVER in envs/deploy.env [NODE_ID=validator-N]" && exit 1); \
	  echo "Pulling peer bundle from $(SEED_SERVER)..."; \
	  $(MAKE) pull-peer-config SERVER="$(SEED_SERVER)" REMOTE_DIR="$(REMOTE_DIR)" \
	    $(if $(filter 1,$(SKIP_REFRESH)),SKIP_REFRESH=1,); \
	fi
	$(MAKE) prepare-new-node TYPE=validator $(if $(NODE_ID),NODE_ID="$(NODE_ID)",)

sync-new-validator: ## Local: rsync genesis + node validator mới lên server remote
	@test -n "$(SERVER)" || (echo "Usage: make sync-new-validator SERVER=user@host NODE_ID=validator-N [REMOTE_DIR=...]" && exit 1)
	@test -n "$(NODE_ID)" || (echo "Usage: make sync-new-validator SERVER=user@host NODE_ID=validator-N [REMOTE_DIR=...]" && exit 1)
	NODE_ID="$(NODE_ID)" $(SCRIPTS)/local/sync-new-validator.sh "$(SERVER)" "$(REMOTE_DIR)" \
		--node-id "$(NODE_ID)" \
		$(if $(filter 1,$(DRY_RUN)),--dry-run,)

_ssh-new-validator-check:
	@test -n "$(SERVER)" || (echo "Usage: make $@ SERVER=user@host NODE_ID=validator-N [REMOTE_DIR=...]" && exit 1)
	@test -n "$(NODE_ID)" || (echo "Usage: make $@ SERVER=user@host NODE_ID=validator-N [REMOTE_DIR=...]" && exit 1)

ssh-new-validator-prepare: _ssh-new-validator-check ## SSH: render env + tạo compose-<NODE_ID> trên server
	NODE_ID="$(NODE_ID)" $(SCRIPTS)/local/ssh-new-validator.sh "$(SERVER)" prepare \
		--remote-dir "$(REMOTE_DIR)" --node-id "$(NODE_ID)" \
		$(if $(filter 1,$(SKIP_RENDER)),--skip-render,)

ssh-new-validator-up: _ssh-new-validator-check ## SSH: prepare (nếu thiếu) + docker compose up validator mới
	NODE_ID="$(NODE_ID)" $(SCRIPTS)/local/ssh-new-validator.sh "$(SERVER)" up \
		--remote-dir "$(REMOTE_DIR)" --node-id "$(NODE_ID)" \
		$(if $(filter 1,$(SKIP_RENDER)),--skip-render,) \
		$(if $(filter 1,$(SKIP_PULL)),--skip-pull,)

ssh-new-validator-down: _ssh-new-validator-check ## SSH: docker compose down validator mới
	NODE_ID="$(NODE_ID)" $(SCRIPTS)/local/ssh-new-validator.sh "$(SERVER)" down \
		--remote-dir "$(REMOTE_DIR)" --node-id "$(NODE_ID)"

ssh-new-validator-logs: _ssh-new-validator-check ## SSH: follow logs validator mới
	NODE_ID="$(NODE_ID)" $(SCRIPTS)/local/ssh-new-validator.sh "$(SERVER)" logs \
		--remote-dir "$(REMOTE_DIR)" --node-id "$(NODE_ID)"

validator-2-prepare-local: ## Deprecated → prepare-new-validator-local
	@echo "Deprecated: use make prepare-new-validator-local SEED_SERVER=..." >&2
	@$(MAKE) prepare-new-validator-local SEED_SERVER="$(or $(SEED_SERVER),$(SERVER))" \
		REMOTE_DIR="$(REMOTE_DIR)" NODE_ID=$(NODE_ID) \
		$(if $(filter 1,$(SKIP_REFRESH)),SKIP_REFRESH=1,)

sync-validator-2: ## Deprecated → sync-new-validator (cần NODE_ID)
	@echo "Deprecated: use make sync-new-validator SERVER=... NODE_ID=validator-N" >&2
	@test -n "$(SERVER)" || (echo "Usage: make sync-validator-2 SERVER=... NODE_ID=validator-N" && exit 1)
	@$(MAKE) sync-new-validator SERVER="$(SERVER)" REMOTE_DIR="$(REMOTE_DIR)" NODE_ID="$(or $(NODE_ID),validator-2)" \
		$(if $(filter 1,$(DRY_RUN)),DRY_RUN=1,)

prepare-validator-2: ## Deprecated → prepare-new-validator-local
	@echo "Deprecated: use make prepare-new-validator-local SEED_SERVER=$(SERVER)" >&2
	@test -n "$(SERVER)" || (echo "Usage: make prepare-validator-2 SERVER=user@seed-host (= SEED_SERVER)" && exit 1)
	@$(MAKE) prepare-new-validator-local SEED_SERVER="$(SERVER)" REMOTE_DIR="$(REMOTE_DIR)" \
		$(if $(filter 1,$(SKIP_REFRESH)),SKIP_REFRESH=1,) \
		NODE_ID=$(NODE_ID)

pull-validator-1-enode: ## Deprecated alias → pull-peer-config
	@echo "Deprecated: use make pull-peer-config" >&2
	@$(MAKE) pull-peer-config SERVER="$(SERVER)" REMOTE_DIR="$(REMOTE_DIR)" \
		$(if $(filter 1,$(SKIP_REFRESH)),SKIP_REFRESH=1,)

patch-spec: ## Phase D: patch-spec-after-deploy.sh
	$(SCRIPTS)/patch-spec-after-deploy.sh

validator-restart: ## Restart validator-1 sau patch spec
	$(SCRIPTS)/restart-validator-1.sh

validator-up: ## docker compose up validator-1 (+ consensus profile)
	$(SCRIPTS)/validator-up.sh

validator-down: ## docker compose down validator stack
	@# shellcheck source=lib/compose.sh
	@source $(SCRIPTS)/lib/compose.sh && chain_dpos_compose $(ROOT) -f compose-validator-1.yml down

stop-validator-nodes: ## Dừng validator stack + deployer containers (giữ chain data)
	$(SCRIPTS)/stop-validator-nodes.sh --force

validator-logs: ## Follow logs validator-1
	@source $(SCRIPTS)/lib/compose.sh && chain_dpos_compose $(ROOT) -f compose-validator-1.yml logs -f --tail=100

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

sync: ## Local: rsync bundle lên server (EXPLORER=1 | SEED=1 | DAPPS=1 | SERVER=)
	@test -n "$(SSH_TARGET)" || (echo "Usage: make sync $(_ssh_usage_hint)" && exit 1)
	$(SCRIPTS)/local/sync-to-server.sh "$(SSH_TARGET)" "$(REMOTE_DIR)"

provision-remote: ## Local: provision Docker trên server
	@test -n "$(SSH_TARGET)" || (echo "Usage: make provision-remote $(_ssh_usage_hint)" && exit 1)
	$(SCRIPTS)/local/provision-remote.sh "$(SSH_TARGET)" \
		$(if $(filter-out /opt/blockchain-dock,$(REMOTE_DIR)),--remote-dir "$(REMOTE_DIR)",) \
		$(if $(filter 1 true,$(OPEN_P2P_PORT)),--open-p2p-port,)

open-p2p-port: ## Server: mở P2P port qua ufw (OPEN_P2P_PORT=1)
	sudo OPEN_P2P_PORT=1 P2P_PORT=$(or $(P2P_PORT),30300) $(SCRIPTS)/remote/open-p2p-port.sh

ssh-open-p2p-port: ## SSH: mở P2P port trên server đích
	@test -n "$(SSH_TARGET)" || (echo "Usage: make ssh-open-p2p-port $(_ssh_usage_hint)" && exit 1)
	$(SCRIPTS)/local/ssh-run-remote.sh "$(SSH_TARGET)" "$(REMOTE_DIR)" \
		sudo OPEN_P2P_PORT=1 P2P_PORT=$(or $(P2P_PORT),30300) ./scripts/remote/open-p2p-port.sh

setup-ssh: ## Local: ssh-copy-id lên server (một lần, không hỏi password sau)
	@test -n "$(SSH_TARGET)" || (echo "Usage: make setup-ssh $(_ssh_usage_hint)" && exit 1)
	$(SCRIPTS)/local/setup-ssh.sh "$(SSH_TARGET)"

install-make-remote: ## Local: cài GNU make trên server (gọi install-make-remote.sh)
	@test -n "$(SSH_TARGET)" || (echo "Usage: make install-make-remote $(_ssh_usage_hint)" && exit 1)
	$(SCRIPTS)/local/install-make-remote.sh "$(SSH_TARGET)"

ssh-install-make: ## SSH: cài GNU make trên server đích (alias install-make-remote)
	@test -n "$(SSH_TARGET)" || (echo "Usage: make ssh-install-make $(_ssh_usage_hint)" && exit 1)
	$(SCRIPTS)/local/install-make-remote.sh "$(SSH_TARGET)"

deploy-remote-validator: ## Server: deploy-validator.sh
	$(SCRIPTS)/remote/deploy-validator.sh $(if $(filter 1,$(WITH_TRAEFIK)),--with-traefik,)

deploy-remote-stop-validator: ## Server: stop-validator-nodes.sh
	$(SCRIPTS)/stop-validator-nodes.sh --force

deploy-remote-dapps: ## Server: deploy-dapps.sh (RPC + netstats + docs + Traefik; no Blockscout)
	$(SCRIPTS)/remote/deploy-dapps.sh

deploy-remote-explorer: ## Server: deploy-explorer.sh (Blockscout only, no netstats-dashboard)
	$(SCRIPTS)/remote/deploy-explorer.sh

ssh-deploy-validator: ## Chạy deploy-validator trên server qua SSH
	@test -n "$(SEED_TARGET)" || (echo "Usage: make ssh-deploy-validator [SERVER=user@host] — or set SEED_SERVER in envs/deploy.env" && exit 1)
	@$(SCRIPTS)/local/ssh-run-remote.sh "$(SEED_TARGET)" "$(REMOTE_DIR)" \
		./scripts/remote/deploy-validator.sh $(if $(filter 1,$(WITH_TRAEFIK)),--with-traefik,) \
	|| { \
		echo ""; \
		echo "=== Deploy failed — stop validator nodes trên server rồi fix & chạy lại ==="; \
		echo "  make ssh-stop-validator-nodes SERVER=$(SEED_TARGET) REMOTE_DIR=$(if $(REMOTE_DIR),$(REMOTE_DIR),/opt/blockchain-dock)"; \
		echo "  make ssh-deploy-validator SERVER=$(SEED_TARGET) REMOTE_DIR=$(if $(REMOTE_DIR),$(REMOTE_DIR),/opt/blockchain-dock)"; \
		exit 1; \
	}

ssh-stop-validator-nodes: ## SSH: dừng validator stack + deployer (giữ chain data)
	@test -n "$(SEED_TARGET)" || (echo "Usage: make ssh-stop-validator-nodes [SERVER=user@host] — or set SEED_SERVER in envs/deploy.env" && exit 1)
	$(SCRIPTS)/local/ssh-run-remote.sh "$(SEED_TARGET)" "$(REMOTE_DIR)" \
		./scripts/stop-validator-nodes.sh --force

ssh-deploy-dapps: ## SSH: deploy-dapps trên DAPPS_SERVER (RPC + DApps; không Blockscout)
	@test -n "$(DAPPS_TARGET)" || (echo "Usage: make ssh-deploy-dapps [SERVER=user@host] — or set DAPPS_SERVER in envs/deploy.env" && exit 1)
	$(SCRIPTS)/local/ssh-run-remote.sh "$(DAPPS_TARGET)" "$(REMOTE_DIR)" \
		./scripts/remote/deploy-dapps.sh

ssh-deploy-explorer: ## Chạy deploy-explorer trên server qua SSH (EXPLORER_SERVER default)
	@test -n "$(EXPLORER_TARGET)" || (echo "Usage: make ssh-deploy-explorer [SERVER=user@host] — or set EXPLORER_SERVER in envs/deploy.env" && exit 1)
	$(SCRIPTS)/local/ssh-run-remote.sh "$(EXPLORER_TARGET)" "$(REMOTE_DIR)" \
		./scripts/remote/deploy-explorer.sh

gtbs-prepare: ## Chuẩn bị deploy GTBS (ENABLE_CUSTOM_STAKING=true trong deploy.env)
	@grep -q 'ENABLE_CUSTOM_STAKING=true' envs/deploy.env || \
		(echo "Set ENABLE_CUSTOM_STAKING=true in envs/deploy.env" && exit 1)
	$(MAKE) prepare-remote WITH_TRAEFIK=$(WITH_TRAEFIK)
