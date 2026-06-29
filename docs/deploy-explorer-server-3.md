# Deploy Explorer (Blockscout v11) lên Server 3

Hướng dẫn triển khai **chỉ Explorer** (RPC archive node + Blockscout v11 + Traefik SSL) từ **máy operator local** lên **server 3** — tách biệt khỏi validator và khỏi các DApps khác.

**Kiến trúc mạng GTBS (ví dụ):**

| Server | Vai trò | Services chính |
|--------|---------|----------------|
| **Server 1** | Seed validator | `openethereum`, `validator-app`, `netstats-api` |
| **Server 2** | Validator bổ sung (tuỳ chọn) | `openethereum` |
| **Server 3** | **Explorer only** | `rpc-node`, Blockscout v11 (backend + frontend + stats + visualizer), Traefik |
| **Server DApps** | DApps còn lại | `netstats-dashboard`, docs, faucet (testnet), Traefik |

> **Lưu ý:** `netstats-dashboard` **không** chạy trên server 3 — deploy chung stack DApps trên server DApps. Xem [remote-deploy.md](./remote-deploy.md) (`deploy-dapps.sh`).  
> Chi tiết Blockscout v11: [explorer-v11.md](./explorer-v11.md).

---

## Giả định

- **Server 1** đã bootstrap xong chain (phase A–F), `make verify` pass.
- **Peer bundle đã capture về local repo** sau seed deploy (xem [remote-deploy.md](./remote-deploy.md) § Capture peer bundle).
- Images đã push lên Docker Hub (`DOCKERHUB_NAMESPACE` trong `deploy.env`).
- Operator có clone đầy đủ monorepo `blockchain-dock` trên máy local.

### Peer bundle (bắt buộc trong local repo)

Explorer cần **cùng genesis** và **peer list** với validator. Các file sau phải có sẵn trong `chain-dpos/genesis/` (capture **một lần** sau seed deploy — **không** kéo lại mỗi lần deploy explorer):

| File | Mục đích |
|------|----------|
| `genesis/spec.json` | Chain spec |
| `genesis/contract-addresses.json` | Địa chỉ contracts |
| `genesis/reserved-peers.txt` | Enode bootstrap |
| `genesis/validator-1.enode` | Enode seed validator |
| `genesis/peers/seed.enode` | Bản sao enode seed |

Nếu thiếu → chạy `make pull-peer-config` **một lần** sau seed setup (Makefile dùng `SEED_SERVER` trong `deploy.env`), rồi commit vào repo.  
Chỉ pull lại khi seed đổi public IP hoặc enode thay đổi.

### Cấu hình SSH trong `envs/deploy.env`

Thiết lập **một lần** trong `envs/deploy.env` — Makefile đọc tự động, **không** cần `export` shell:

```env
REMOTE_DEPLOY_DIR=/opt/blockchain-gtbs
SEED_SERVER=root@91.229.245.75
EXPLORER_SERVER=root@203.0.113.60
DAPPS_SERVER=root@203.0.113.70
```

| Biến `deploy.env` | Ví dụ | Ghi chú |
|-------------------|--------|---------|
| `SEED_SERVER` | `root@91.229.245.75` | SSH server 1 — `pull-peer-config`, `make sync SEED=1`, … |
| `EXPLORER_SERVER` | `root@203.0.113.60` | SSH server 3 — `make sync EXPLORER=1`, `ssh-deploy-explorer`, … |
| `DAPPS_SERVER` | `root@203.0.113.70` | SSH server DApps — `make sync DAPPS=1`, `ssh-deploy-dapps` |
| `REMOTE_DEPLOY_DIR` | `/opt/blockchain-gtbs` | Thư mục deploy trên server → Make `REMOTE_DIR` |
| `EXPLORER_SERVER_NAME` | `gtbsblockchain.com` | **Domain** HTTPS explorer (khác `EXPLORER_SERVER`) |

Thư mục chain trên server: `${REMOTE_DEPLOY_DIR}/blockchain-dockerize/docker-compose/chain-dpos`.

### Cờ chọn server

Lệnh `sync`, `provision-remote`, `setup-ssh`, `sync-peer-bundle`, `ssh-open-p2p-port` **bắt buộc** một trong:

- `EXPLORER=1` → dùng `EXPLORER_SERVER`
- `SEED=1` → dùng `SEED_SERVER`
- `DAPPS=1` → dùng `DAPPS_SERVER`
- `SERVER=root@host` → host tùy ý (validator mới, override, …)

`make ssh-deploy-explorer` tự dùng `EXPLORER_SERVER` (không cần cờ).

> **Override:** `make sync SERVER=root@other-host` ưu tiên hơn mọi cờ.

Chi tiết biến Make: [makefile.md](./makefile.md) § SSH targets trong `deploy.env`.

---

## Lệnh `make` nhanh (máy operator)

Chạy trong `blockchain-dockerize/docker-compose/chain-dpos`:

```bash
cd blockchain-dockerize/docker-compose/chain-dpos

# Phase 0 — một lần (sau khi set *_SERVER / REMOTE_DEPLOY_DIR trong deploy.env)
make init && $EDITOR envs/deploy.env
make setup-ssh EXPLORER=1
make provision-remote EXPLORER=1

# Phase A — chuẩn bị RPC node local (dùng peer bundle trong repo)
make prepare-new-node TYPE=rpc

# Phase B — render env + genesis (cần WITH_TRAEFIK=1)
make render WITH_TRAEFIK=1

# Phase C — sync bundle + peer artifacts lên server 3
make sync EXPLORER=1
make sync-peer-bundle EXPLORER=1

# Phase D — deploy explorer trên server 3 (không gồm netstats-dashboard)
make ssh-open-p2p-port EXPLORER=1
make ssh-deploy-explorer
```

> **Không chạy `make prepare-remote`** khi chỉ deploy/redeploy explorer — target đó chạy `prepare-genesis.sh` và có thể **ghi đè** `genesis/spec.json` local. Dùng `make render WITH_TRAEFIK=1` + `make sync EXPLORER=1` thay thế.

> `deploy-dapps.sh` / `make ssh-deploy-dapps` chỉ khởi động DApps (`netstats-dashboard`, docs, faucet) — **không** gồm Blockscout/RPC. **Không dùng** trên server 3 (explorer).

---

## Tổng quan luồng

```
[Server 1 — đã chạy]
  validator-1 + netstats-api
  export-peer-config.sh → capture peer bundle về local repo (một lần)

[Máy operator local]
  genesis/ peer bundle đã có trong repo
  → deploy.env: SEED_SERVER, EXPLORER_SERVER, secrets, domain explorer
  → prepare-new-node TYPE=rpc (lần đầu)
  → make render WITH_TRAEFIK=1
  → sync EXPLORER=1 + sync-peer-bundle EXPLORER=1

[Server 3 — explorer only]
  DNS → IP server 3 (explorer, stats, visualize, RPC)
  mở P2P 30300 (RPC node sync chain)
  deploy-explorer.sh (tự chown Postgres + GTBS override nếu bật)
  → rpc-node sync từ validator qua reserved-peers
  → Blockscout index blocks

[Server DApps — riêng biệt]
  DNS → IP server DApps (status, docs, faucet)
  deploy-dapps.sh → netstats-dashboard + docs-static + Traefik
  → netstats-dashboard + docs + faucet
```

---

## Phase 0 — Chuẩn bị máy operator

### 0.1 — Tool cần có

```bash
make check-deps   # docker (local build tùy chọn), jq, node, rsync, ssh
```

### 0.2 — SSH key lên server 3

```bash
make setup-ssh EXPLORER=1
ssh -o BatchMode=yes "$(grep '^EXPLORER_SERVER=' envs/deploy.env | cut -d= -f2-)" "echo ok"
```

### 0.3 — Provision server 3 (một lần)

```bash
make provision-remote EXPLORER=1
```

Cài Docker 20.10+, Compose v2, Node 18+, `jq`, `curl`, `rsync`.

### 0.4 — Custom address prefix (tuỳ chọn)

Trong `envs/deploy.env` (trước `make prepare-remote` / `./scripts/render-envs.sh`):

```bash
ADDRESS_DISPLAY_PREFIX=custom1
ADDRESS_DISPLAY_DEFAULT=bech32
ADDRESS_FORMAT_TOGGLE=true
```

Để trống `ADDRESS_DISPLAY_PREFIX` → explorer hiển thị `0x` chuẩn. Chi tiết: [explorer-v11.md](./explorer-v11.md) § Custom address prefix.

---

## Phase A — Chuẩn bị RPC node local

Dùng peer bundle **đã có trong repo** (không cần `pull-peer-config`):

```bash
make prepare-new-node TYPE=rpc
# Tạo nodes/rpc/ (config.toml, reserved-peers.txt)
```

Nếu thiếu `genesis/reserved-peers.txt` hoặc `genesis/spec.json` → capture từ seed trước (xem [remote-deploy.md](./remote-deploy.md) § Capture peer bundle).

---

## Phase B — Cấu hình `deploy.env`

Mở `envs/deploy.env` và **khớp hoàn toàn** với server 1 về chain identity. Đồng thời set SSH targets (xem § Cấu hình SSH ở trên):

```env
REMOTE_DEPLOY_DIR=/opt/blockchain-gtbs
SEED_SERVER=root@91.229.245.75
EXPLORER_SERVER=root@203.0.113.60
DAPPS_SERVER=root@203.0.113.70

NETWORK_NAME=GTBS
NETWORK_ID=0x9C46
NETWORK_TYPE=mainnet
BLOCK_TIME_SECONDS=3
CONTRACT_TRANSITION_BLOCK=200
PREMINE_ADDRESS=0x...
DOCKERHUB_NAMESPACE=congquang295
```

### Domain — Server 3 (explorer)

Trỏ A record về **IP server 3**:

```env
ACME_EMAIL=admin@example.com
RPC_SERVER_NAME=mainnet-rpc.gtbsblockchain.com
EXPLORER_SERVER_NAME=gtbsblockchain.com
STATS_SERVER_NAME=stats.gtbsblockchain.com
VISUALIZE_SERVER_NAME=visualize.gtbsblockchain.com
TRAEFIK_DASHBOARD_HOST=traefik-explorer.example.com   # tuỳ chọn
```

### Domain — Server DApps (không chạy trên server 3)

Trỏ A record về **IP server DApps** (deploy riêng):

```env
STATUS_SERVER_NAME=status.gtbsblockchain.com
DOCS_SERVER_NAME=docs.gtbsblockchain.com
FAUCET_SERVER_NAME=faucet.gtbsblockchain.com
```

### Secrets (Postgres + Blockscout) — bắt buộc trước deploy đầu tiên

Ghi **cố định** vào `deploy.env` (tránh password drift khi redeploy):

```env
POSTGRES_PASSWORD=<openssl rand -hex 32>
STATS_DB_PASSWORD=<openssl rand -hex 32>
SECRET_KEY_BASE=<openssl rand -hex 64>
POSTGRES_DB=blockscout
```

| Biến | Dùng cho |
|------|----------|
| `POSTGRES_PASSWORD` | Blockscout DB (`db`) |
| `STATS_DB_PASSWORD` | Stats DB (`stats-db`) |
| `SECRET_KEY_BASE` | Blockscout backend |

> `WS_SECRET` chỉ cần cho **netstats dashboard** trên server DApps — **không** dùng trên explorer-only server.

### Explorer branding (GTBS — khuyến nghị)

```env
EXPLORER_CUSTOM_PROFILE=gtbs
EXPLORER_HERO_TITLE="GTBS Blockchain Explorer"
EXPLORER_ASSETS_BASE_URL=https://raw.githubusercontent.com/gtbschain/assets/master/explorer
COIN_NAME=GTBS
COIN_SYMBOL=GTBS
```

Logo/icon tải từ GitHub khi frontend start — server cần outbound `raw.githubusercontent.com`.  
`make ssh-deploy-explorer` tự merge GTBS env + compose override. Chi tiết: [explorer-custom-theme.md](./explorer-custom-theme.md).

### Render env

```bash
make render WITH_TRAEFIK=1
```

Sinh `envs/*.env`, `images.env`, Traefik, Blockscout backend/frontend.

**GTBS widgets:** `NEXT_PUBLIC_CONSENSUS_ADDRESS` / `NEXT_PUBLIC_STAKING_VAULT_ADDRESS` tự inject từ `genesis/contract-addresses.json` khi `EXPLORER_CUSTOM_PROFILE=gtbs`.

> **Không** dùng `make prepare-remote` cho luồng explorer-only — target đó chạy `prepare-genesis.sh` và có thể ghi đè genesis local. Chỉ dùng khi bootstrap chain GTBS mới từ đầu.

---

## Phase C — Sync bundle lên Server 3

```bash
make sync EXPLORER=1
```

Đồng bộ: compose, scripts, env đã render, `genesis/spec.json`, `nodes/rpc/` (không có chain DB), `docker-compose/services/`, `dpos-contracts` (scripts tham chiếu compose).

**Không** sync: `nodes/*/data/`, `data/` (DB và chain data tạo mới trên server 3).

**Chỉ chạy lại `make sync EXPLORER=1`** khi đổi compose / scripts / env đã render. Cập nhật riêng peer bundle → chỉ `make sync-peer-bundle EXPLORER=1` (không cần full sync).

### 4b — Sync peer bundle (bắt buộc, sau `make sync EXPLORER=1` lần đầu)

`sync-to-server.sh` **loại trừ** các artifact peer (tránh ghi đè validator seed). `genesis/spec.json` **đã** được `make sync EXPLORER=1` đẩy lên.

```bash
make sync-peer-bundle EXPLORER=1
```

Đẩy từ local repo:

- `genesis/contract-addresses.json`
- `genesis/reserved-peers.txt`
- `genesis/validator-1.enode`
- `genesis/peers/`

> Chạy lại `make sync EXPLORER=1` sau `sync-peer-bundle` **không** xoá peer files trên server 3 (rsync exclude giữ nguyên file đích).

Kiểm tra trên server 3:

```bash
ssh "$(grep '^EXPLORER_SERVER=' envs/deploy.env | cut -d= -f2-)" \
  "ls -la $(grep '^REMOTE_DEPLOY_DIR=' envs/deploy.env | cut -d= -f2-)/blockchain-dockerize/docker-compose/chain-dpos/genesis/reserved-peers.txt \
         $(grep '^REMOTE_DEPLOY_DIR=' envs/deploy.env | cut -d= -f2-)/blockchain-dockerize/docker-compose/chain-dpos/nodes/rpc/"
```

---

## Phase D — DNS & Firewall (Server 3)

Trước khi deploy, trỏ **A record** các domain explorer về **IP public server 3**:

| Domain env | Service |
|------------|---------|
| `EXPLORER_SERVER_NAME` | Blockscout frontend + API |
| `STATS_SERVER_NAME` | Blockscout stats microservice |
| `VISUALIZE_SERVER_NAME` | Blockscout visualizer |
| `RPC_SERVER_NAME` | JSON-RPC public |

| Cổng | Mục đích |
|------|----------|
| **80**, **443** | Traefik + Let's Encrypt |
| **30300** TCP/UDP | P2P — RPC archive node sync chain từ validator |

```bash
make ssh-open-p2p-port EXPLORER=1
```

**Server 1** cũng cần P2P `30300` mở public để RPC node trên server 3 peering được.

> RPC JSON (`8545`) **không** bind public — chỉ expose qua Traefik domain `RPC_SERVER_NAME`.

---

## Phase E — Deploy Explorer trên Server 3

**Không** dùng `deploy-dapps.sh` trên server 3 — script đó dành cho server DApps (`netstats-dashboard`, `docs-static`, `eth-faucet`).

### Cách A — Từ máy operator (khuyến nghị)

```bash
make ssh-deploy-explorer
```

Script `deploy-explorer.sh` sẽ:

1. `render-envs.sh --with-traefik`
2. `prepare-rpc-node.sh` + `prepare-envs-dapps.sh`
3. Chạy `db-init` + `stats-db-init` và **chown** Postgres data dirs (`UID 2000`)
4. `docker compose up` services explorer (tự thêm GTBS override nếu `EXPLORER_CUSTOM_PROFILE=gtbs`)
5. `health-check.sh`

### Redeploy sạch (wipe data + deploy lại)

Khi cần xóa Blockscout DB + RPC chain data trên server explorer (giữ genesis):

```bash
# Từ máy operator
make ssh-clean-explorer EXPLORER=1
make sync EXPLORER=1
make sync-peer-bundle EXPLORER=1
make ssh-deploy-explorer
```

Hoặc SSH thủ công: `./scripts/remote/clean-explorer.sh --force` rồi `./scripts/remote/deploy-explorer.sh`.

### Cách B — SSH thủ công

```bash
# Thay bằng giá trị EXPLORER_SERVER / REMOTE_DEPLOY_DIR trong deploy.env
ssh root@203.0.113.60
cd /opt/blockchain-gtbs/blockchain-dockerize/docker-compose/chain-dpos

./scripts/render-envs.sh envs/deploy.env --with-traefik
./scripts/prepare-rpc-node.sh
WITH_TRAEFIK_PREPARE=true ./scripts/prepare-envs-dapps.sh
./scripts/remote/deploy-explorer.sh
```

**Services trên server 3:**

| Service | Mục đích |
|---------|----------|
| `traefik` | SSL + reverse proxy |
| `openethereum` | RPC archive node (sync chain) |
| `db`, `db-init`, `redis-db` | Postgres + Redis cho Blockscout |
| `backend`, `frontend` | Blockscout v11 |
| `stats`, `stats-db`, `stats-db-init` | Blockscout stats |
| `visualizer` | Blockscout visualizer |

**Không start trên server 3:** `netstats-dashboard`, `docs-static`, `eth-faucet`.

### GTBS profile

Tự động khi `EXPLORER_CUSTOM_PROFILE=gtbs` trong `deploy.env` — **không** cần thêm cờ compose thủ công. `deploy-explorer.sh` thêm `overrides/v11/blockscout-frontend-gtbs.override.yml` (`SKIP_ENVS_VALIDATION` cho custom env vars).

---

## Phase F — Deploy DApps (netstats dashboard + …) trên Server DApps

`netstats-dashboard` deploy **cùng** các DApps khác trên server riêng — **không** phải server 3.

Stack trên server DApps: **RPC archive** (`openethereum`), Traefik, `netstats-dashboard`, `docs-static` (+ `eth-faucet` nếu testnet). **Không** gồm Blockscout (chạy trên server 3).

### Peer bundle — bắt buộc trước deploy

RPC node trên server DApps sync chain qua `genesis/reserved-peers.txt`. File này **phải khớp** enode validator đang chạy (seed + validator bổ sung nếu có).

Kiểm tra local (ví dụ GTBS):

```bash
cat genesis/reserved-peers.txt
# enode://...@91.229.245.75:30300   ← seed validator
# enode://...@185.202.236.10:30300  ← validator bổ sung (nếu có)
```

Nếu thiếu hoặc enode cũ (sau redeploy seed / đổi keystore):

```bash
make pull-peer-config          # kéo từ SEED_SERVER
make prepare-new-node TYPE=rpc # copy reserved-peers → nodes/rpc/
```

> `make sync DAPPS=1` **không** đẩy `genesis/reserved-peers.txt` (tránh ghi đè seed). Sau `sync` bắt buộc `make sync-peer-bundle DAPPS=1`.

### WS_SECRET — bắt buộc khớp Server 1

`netstats-api` (server 1) và `netstats-dashboard` (server DApps) dùng **cùng** `WS_SECRET`:

```bash
ssh "$(grep '^SEED_SERVER=' envs/deploy.env | cut -d= -f2-)" \
  "grep '^WS_SECRET=' $(grep '^REMOTE_DEPLOY_DIR=' envs/deploy.env | cut -d= -f2-)/blockchain-dockerize/docker-compose/chain-dpos/envs/deploy.env"
```

Gán vào `envs/deploy.env` local trước khi sync lên server DApps.

### Deploy lần đầu (từ máy operator — chỉ `make`, không SSH thủ công)

```bash
cd blockchain-dockerize/docker-compose/chain-dpos

# 0. Peer bundle + RPC config local
make pull-peer-config          # nếu genesis/reserved-peers.txt thiếu hoặc cũ
make prepare-new-node TYPE=rpc
make render WITH_TRAEFIK=1

# 1. Sync bundle (compose, env, scripts)
make sync DAPPS=1

# 2. Đẩy peer bundle lên server DApps
make sync-peer-bundle DAPPS=1

# 3. Deploy
make ssh-open-p2p-port DAPPS=1   # một lần — mở P2P 30300
make ssh-deploy-dapps
```

### Redeploy sạch (xóa RPC data + images cũ)

```bash
make sync DAPPS=1
make ssh-clean-dapps PRUNE_IMAGES=1
make sync-peer-bundle DAPPS=1
make prepare-new-node TYPE=rpc
make sync DAPPS=1
make ssh-deploy-dapps SKIP_HEALTH=1   # archive sync > 180s; health-check sau
```

Health-check sau khi RPC đã peer (2+ peers trong logs):

```bash
# Từ local, qua SSH (timeout dài hơn mặc định 180s):
./scripts/local/ssh-run-remote.sh "$(grep '^DAPPS_SERVER=' envs/deploy.env | cut -d= -f2-)" \
  "$(grep '^REMOTE_DEPLOY_DIR=' envs/deploy.env | cut -d= -f2-)" \
  env HEALTH_CHECK_TIMEOUT=900 ./scripts/health-check.sh
```

Chi tiết đầy đủ: [remote-deploy.md](./remote-deploy.md), [netstats.md](./netstats.md).

### Troubleshooting DApps server

| Triệu chứng | Nguyên nhân | Cách xử lý |
|-------------|-------------|------------|
| `RPC node did not sync in time` (health-check) | Archive sync từ block 0 > 180s | `make ssh-deploy-dapps SKIP_HEALTH=1`, chờ sync, chạy health-check với `HEALTH_CHECK_TIMEOUT=900` |
| RPC `0/25 peers`, chain 1 KiB | `reserved-peers.txt` cũ trên server | `make pull-peer-config` → `make sync-peer-bundle DAPPS=1` → `make prepare-new-node TYPE=rpc` → `make sync DAPPS=1` → redeploy |
| Peers file đúng nhưng vẫn 0 peer | Container RPC chưa đọc lại mount | `deploy-dapps.sh` tự `--force-recreate openethereum`; hoặc redeploy sau `ssh-clean-dapps` |
| Netstats dashboard offline | `WS_SECRET` không khớp server 1 | Đồng bộ `WS_SECRET` trong `deploy.env`, `make sync DAPPS=1`, redeploy |

**Không** dùng lệnh `docker` trực tiếp trên server khi có thể — dùng các target `make` ở trên.

---

## Phase G — Kiểm tra

### Health check (server 3)

```bash
make ssh-deploy-explorer SKIP_HEALTH=0   # health-check chạy cuối deploy-explorer.sh
# hoặc SSH thủ công:
ssh "$(grep '^EXPLORER_SERVER=' envs/deploy.env | cut -d= -f2-)" \
  "cd $(grep '^REMOTE_DEPLOY_DIR=' envs/deploy.env | cut -d= -f2-)/blockchain-dockerize/docker-compose/chain-dpos && ./scripts/health-check.sh"
```

### RPC node đã sync

```bash
ssh "$(grep '^EXPLORER_SERVER=' envs/deploy.env | cut -d= -f2-)" \
  "curl -s -X POST http://127.0.0.1:8545 \
  -H 'Content-Type: application/json' \
  -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}'"
```

Block number phải tăng dần (không kẹt ở `0x0` lâu).

### Explorer (server 3)

- `https://${EXPLORER_SERVER_NAME}` — homepage Blockscout
- `https://${EXPLORER_SERVER_NAME}/api/v2/stats`
- `https://${STATS_SERVER_NAME}` — Blockscout stats
- `https://${VISUALIZE_SERVER_NAME}` — visualizer
- `https://${RPC_SERVER_NAME}` — JSON-RPC

### Netstats dashboard (server DApps)

- `https://${STATUS_SERVER_NAME}` — network status UI
- Validator-1 (server 1) phải hiện **online**

Nếu offline:

- `WS_SECRET` khớp giữa server 1 và server DApps
- `netstats-api` đang chạy trên server 1
- Firewall: dashboard kết nối WebSocket tới netstats API

---

## Troubleshooting

### `db-init` / `stats-db-init` container `Exited (0)` — bình thường

Hai container one-shot chuẩn bị quyền thư mục Postgres (`chown 2000:2000`) rồi thoát. Services thật là `db` và `stats-db` (phải `Up`, `healthy`).

### Bad Gateway (502) trên explorer domain

| Triệu chứng | Nguyên nhân | Cách xử lý |
|-------------|-------------|------------|
| `blockscout-frontend` `Restarting` | Tải logo/icon từ GitHub thất bại | Kiểm tra outbound `raw.githubusercontent.com` từ container; env phải dùng `https://` URL từ `EXPLORER_ASSETS_BASE_URL`, **không** `file://` |
| Frontend crash `Congruity check failed` | GTBS custom env (`STAKING_VAULT`) | Bật `EXPLORER_CUSTOM_PROFILE=gtbs` — override set `SKIP_ENVS_VALIDATION=true` |
| `blockscout-backend` down | Postgres `db` lỗi | Xem mục stats/Postgres bên dưới |

```bash
docker logs blockscout-frontend --tail 30
docker ps -a | grep -E 'frontend|backend|stats'
```

### Stats lỗi / `stats.gtbsblockchain.com` 502

| Log | Nguyên nhân | Cách xử lý |
|-----|-------------|------------|
| `pg_filenode.map: Permission denied` | `stats-db` data dir owner `root` thay vì `2000` | Chạy lại deploy: `./scripts/remote/deploy-explorer.sh` (tự chown), hoặc `chown -R 2000:2000 docker-compose/services/data/dpos-stats-db` rồi `docker compose restart stats-db stats` |

Postgres data nằm tại: `docker-compose/services/data/dpos-blockscout-db` và `dpos-stats-db` (bind mount, **không** phải Docker named volume).

### `Missing peer bundle` khi deploy

Chạy lại `make sync-peer-bundle EXPLORER=1` — `genesis/reserved-peers.txt` phải có trên server 3.

### Blockscout không sync block

| Nguyên nhân | Cách xử lý |
|-------------|------------|
| RPC node chưa sync | Đợi sync; kiểm tra P2P `30300` cả hai server |
| Sai `CHAIN_ID` | `deploy.env` `NETWORK_ID` phải khớp server 1; chạy lại `prepare-remote` |
| RPC chưa sẵn sàng | `docker logs` container `openethereum` (rpc profile) |

```bash
docker compose -f compose-dapps-traefik-v11.yml logs -f openethereum backend
```

### ACME / SSL lỗi

- DNS chưa propagate — đợi TTL
- Port 80/443 chưa mở
- Domain explorer trỏ sai IP (phải là server 3)

### `health-check` fail — Blockscout API

Lần đầu index có thể mất vài phút:

```bash
# Trên server 3 (SSH thủ công)
docker compose -f compose-dapps-traefik-v11.yml logs -f backend --tail=50
```

### Khởi động lại chỉ explorer (server 3)

```bash
# SSH vào server 3, cd chain-dpos — dùng cùng compose args như deploy-explorer.sh:
./scripts/remote/deploy-explorer.sh
# hoặc restart nhanh (không re-chown postgres):
docker compose -f compose-dapps-traefik-v11.yml \
  $(grep -q '^EXPLORER_CUSTOM_PROFILE=gtbs' envs/deploy.env && echo '-f overrides/v11/blockscout-frontend-gtbs.override.yml') \
  restart traefik openethereum backend frontend stats visualizer
```

---

## Checklist

**Server 3 (explorer):**

- [ ] Server 1: chain chạy, `verify` pass, peer bundle đã capture về local repo
- [ ] Local: `prepare-new-node TYPE=rpc` (lần đầu; peer bundle trong `genesis/`)
- [ ] `deploy.env`: secrets (`POSTGRES_PASSWORD`, `STATS_DB_PASSWORD`, `SECRET_KEY_BASE`), `EXPLORER_SERVER`, domains
- [ ] `EXPLORER_CUSTOM_PROFILE=gtbs` + `EXPLORER_ASSETS_BASE_URL` (nếu dùng GTBS theme)
- [ ] `make render WITH_TRAEFIK=1` (không `prepare-remote` khi chỉ deploy explorer)
- [ ] `make sync EXPLORER=1` + `make sync-peer-bundle EXPLORER=1`
- [ ] Firewall server 3: 80, 443, 30300; outbound HTTPS tới GitHub
- [ ] `make ssh-deploy-explorer` (không `deploy-dapps.sh`)
- [ ] Explorer + stats HTTPS hoạt động, blocks đang index

**Server DApps (netstats + …):**

- [ ] Domain status/docs/faucet → IP server DApps
- [ ] `WS_SECRET` khớp server 1
- [ ] `make ssh-deploy-dapps` (cần `DAPPS_SERVER` trong deploy.env)
- [ ] Netstats dashboard thấy validator-1 online

---

## Liên quan

| Tài liệu | Nội dung |
|----------|----------|
| [remote-deploy.md](./remote-deploy.md) | Deploy DApps (netstats dashboard, …) lên server DApps |
| [explorer-v11.md](./explorer-v11.md) | Kiến trúc Blockscout v11 |
| [explorer-custom-theme.md](./explorer-custom-theme.md) | Branding GTBS |
| [netstats.md](./netstats.md) | Cấu hình netstats-api / dashboard |
| [traefik.md](./traefik.md) | Traefik + SSL |
| [setup-new-validator-remote.md](./setup-new-validator-remote.md) | Thêm validator trên server 2 |
| [validator-1-custom-contracts.md](./validator-1-custom-contracts.md) | Deploy validator + contracts GTBS |
| [makefile.md](./makefile.md) | Toàn bộ target Make |
