# Setup new validator trên server remote

Hướng dẫn thêm **validator mới** (non-seed) vào mạng DPoS đã chạy trên **seed host** (validator-1).

**Giả định:**

- Seed host đã bootstrap xong: chain chạy, `export-peer-config.sh` đã chạy, P2P port `30300` mở public.
- Chain **không dùng bootnode** — peering qua static enode trong `reserved-peers.txt`.
- **Stake** (`MIN_STAKE_TOKENS`) làm thủ công sau — không nằm trong guide này.

**Biến mẫu** — cấu hình trong `envs/deploy.env` (Makefile đọc tự động) hoặc truyền trên CLI:

| Biến | Ví dụ | Ghi chú |
|------|--------|---------|
| `SEED_SERVER` | `root@91.229.245.75` | Host chạy validator-1 — trong `deploy.env` |
| `REMOTE_DEPLOY_DIR` | `/opt/blockchain-gtbs` | Thư mục deploy trên server — trong `deploy.env` |
| `SERVER` (CLI) | `root@185.202.236.10` | Host validator **mới** — bắt buộc truyền (chưa có biến `deploy.env` riêng) |
| `NODE_ID` | `validator-2` | Tên thư mục `nodes/<NODE_ID>/` — **luôn dùng** `validator-N`, không dùng số thuần (`2`) |
| `P2P_PUBLIC_IP` (trên server validator) | `185.202.236.10` | IP public của server validator mới — **không** copy IP seed |

```env
# envs/deploy.env — ví dụ
REMOTE_DEPLOY_DIR=/opt/blockchain-gtbs
SEED_SERVER=root@91.229.245.75
```

---

## Lệnh `make` trên máy operator

Chạy trong `blockchain-dockerize/docker-compose/chain-dpos`. Xem đầy đủ: `make help`.

| Target | Mô tả |
|--------|--------|
| `make check-deps` | Kiểm tra docker, jq, node |
| `make init` | Copy `deploy.env.example` |
| `make render` | Render env từ `deploy.env` |
| `make setup-ssh SERVER=...` | SSH key lên server (một lần) |
| `make provision-remote SERVER=... OPEN_P2P_PORT=1` | Cài Docker + tool trên server |
| **`make prepare-new-validator-local`** | **Tạo `nodes/<NODE_ID>/`** (tự skip pull nếu peer bundle đã có local; `SEED_SERVER` từ `deploy.env`) |
| `make pull-peer-config` | Chỉ kéo bundle từ seed (`SEED_SERVER` trong `deploy.env`) |
| `make sync-peer-bundle EXPLORER=1` | Đẩy peer bundle lên explorer (`EXPLORER_SERVER`) |
| `make prepare-new-node TYPE=validator [NODE_ID=...]` | Chỉ tạo keystore (cần bundle sẵn; auto `validator-N` nếu bỏ `NODE_ID`) |
| **`make sync-new-validator SERVER=... NODE_ID=...`** | **Rsync node validator mới lên server remote** |
| **`make ssh-new-validator-prepare SERVER=... NODE_ID=...`** | **SSH: render env + tạo `compose-<NODE_ID>.yml` trên server (bắt buộc trước `up`)** |
| **`make ssh-new-validator-up SERVER=... NODE_ID=...`** | **SSH: docker compose up trên server** |
| `make ssh-new-validator-down / logs` | SSH: down / follow logs |
| `make sync SEED=1` \| `EXPLORER=1` \| `SERVER=...` | Rsync full bundle — chọn server bằng cờ hoặc `SERVER=` |

**Luồng make gọn (local):**

```bash
cd blockchain-dockerize/docker-compose/chain-dpos

# Biến — thay IP thật
export NODE_ID=validator-2
export VALIDATOR_SERVER=root@185.202.236.10
export VALIDATOR_IP=185.202.236.10

# Phase 0 — một lần (set SEED_SERVER + REMOTE_DEPLOY_DIR trong deploy.env)
make init && $EDITOR envs/deploy.env && make render
make setup-ssh SERVER="${VALIDATOR_SERVER}"
make provision-remote SERVER="${VALIDATOR_SERVER}" OPEN_P2P_PORT=1

# Phase A — chuẩn bị validator mới trên local (SEED_SERVER từ deploy.env)
make prepare-new-validator-local NODE_ID="${NODE_ID}" SKIP_PULL=1   # bỏ SKIP_PULL nếu chưa có genesis local

# Ghi address validator (dùng stake sau)
cat "nodes/${NODE_ID}/address"

# Phase B — đẩy bundle tối thiểu lên server remote
make sync-new-validator SERVER="${VALIDATOR_SERVER}" NODE_ID="${NODE_ID}"

# Phase C — sửa P2P_PUBLIC_IP trên server validator (không dùng IP seed)
ssh "${VALIDATOR_SERVER}" "sed -i 's/^P2P_PUBLIC_IP=.*/P2P_PUBLIC_IP=${VALIDATOR_IP}/' \
  /opt/blockchain-gtbs/blockchain-dockerize/docker-compose/chain-dpos/envs/deploy.env"

# Phase C+D — generate compose + env trên server (BẮT BUỘC)
make ssh-new-validator-prepare SERVER="${VALIDATOR_SERVER}" NODE_ID="${NODE_ID}"

# Phase E — start validator
make ssh-new-validator-up SERVER="${VALIDATOR_SERVER}" NODE_ID="${NODE_ID}"

# Phase F+G — lấy enode public, đăng ký lên seed (xem bên dưới)
```

> **Quan trọng:** Luôn chạy `ssh-new-validator-prepare` **trước** `ssh-new-validator-up`. Repo có file stub `compose-validator-2.yml` (chỉ comment, không có services). `sync-new-validator` có thể copy stub này lên server — khi đó `new-validator-up.sh` thấy file đã tồn tại và **bỏ qua** prepare → lỗi `no service selected`.

Các bước **seed host** (`add-peer-enode`) chưa có target `make` — xem phase G.

---

## Tổng quan luồng

```
[Phase 0 — một lần]
  Operator: clone repo, cài tool, deploy.env
  Server remote: setup-ssh → provision-remote (Docker, jq, …)

[Máy operator]
  prepare-new-validator-local (pull + prepare-new-node)
  → sync-new-validator NODE_ID=...

[Server remote]
  sửa P2P_PUBLIC_IP = IP public server validator
  → ssh-new-validator-prepare (render env + compose-<NODE_ID>.yml)
  → ssh-new-validator-up
  → mở P2P 30300 (provision hoặc open-p2p-port.sh)
  → lấy enode public (docker logs)

[Seed host]
  add-peer-enode.sh <enode> --peer-id <NODE_ID>
  → restart validator-1 openethereum
```

---

## Phase 0 — Setup môi trường (một lần)

Chạy **trước** Phase A nếu server remote hoặc máy operator chưa sẵn sàng.

### 0.1 Máy operator

**Yêu cầu:** Ubuntu/Debian hoặc tương đương, clone full repo `blockchain-dock` (cần cả `blockchain-docker-base` + `blockchain-dockerize`).

```bash
git clone <repo-url> blockchain-dock
cd blockchain-dock/blockchain-dockerize/docker-compose/chain-dpos
```

Cài dependency (nếu thiếu):

| Tool | Dùng cho |
|------|----------|
| `docker` + `docker compose` v2 | Kiểm tra local (optional) |
| `node` 18+ | `prepare-new-node` (tạo keystore) |
| `jq` | Đọc JSON / RPC |
| `rsync`, `ssh` | Sync lên server remote |
| `make` | Wrapper `pull-peer-config`, `prepare-new-node` |
| `git` | Clone repo |

```bash
# Ubuntu/Debian — ví dụ
sudo apt-get update
sudo apt-get install -y jq rsync git make curl openssh-client

# Node 18+ (nếu chưa có)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Kiểm tra
make check-deps
```

SSH key (nếu chưa có):

```bash
ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)"
```

**`deploy.env` trên operator** — dùng khi render/sync; phải **khớp chain** với seed:

```bash
make init   # copy deploy.env.example nếu chưa có
```

Chỉnh `envs/deploy.env`:

| Biến | Ghi chú |
|------|---------|
| `NETWORK_NAME`, `NETWORK_ID`, `NETWORK_TYPE` | Giống seed |
| `DOCKERHUB_NAMESPACE` | Namespace image trên Docker Hub |
| `REMOTE_DEPLOY_DIR` | Thường `/opt/blockchain-gtbs` — Make đọc làm `REMOTE_DIR` |
| `SEED_SERVER` | SSH seed host — `pull-peer-config`, `prepare-new-validator-local` |
| `P2P_PORT` | `30300` |

> Có thể copy `deploy.env` từ seed host thay vì tạo mới — đảm bảo `NETWORK_*` và `DOCKERHUB_NAMESPACE` không lệch.

```bash
./scripts/render-envs.sh envs/deploy.env
```

### 0.2 Server remote — SSH + provision (chạy trước khi rsync)

Server remote: Ubuntu/Debian, user có `sudo`, port SSH mở.

**Bước 1 — SSH key (một lần, từ operator):**

```bash
cd blockchain-dockerize/docker-compose/chain-dpos

make setup-ssh SERVER=root@<IP_VALIDATOR_MOI>
# hoặc: ./scripts/local/setup-ssh.sh root@<IP_VALIDATOR_MOI>
```

**Bước 2 — Cài Docker, Compose, Node, jq, rsync, tạo thư mục deploy:**

```bash
make provision-remote SERVER=root@<IP_VALIDATOR_MOI> OPEN_P2P_PORT=1
```

`REMOTE_DIR` lấy từ `REMOTE_DEPLOY_DIR` trong `deploy.env`. `provision-remote` chạy `scripts/remote/provision-server.sh` trên server remote và cài:

- Docker CE + Compose plugin v2
- Node.js 18+, `jq`, `curl`, `rsync`, `git`, `make`
- Thư mục deploy (owner = user SSH)
- *(Tuỳ chọn)* Mở ufw port `30300` TCP/UDP khi `OPEN_P2P_PORT=1`

Kiểm tra trên server remote:

```bash
ssh root@<IP_VALIDATOR_MOI> "docker --version && docker compose version && jq --version && node -v"
```

> **Thứ tự:** Phase 0.2 (provision) **trước** Phase B (rsync). Doc cũ đặt provision ở Phase C — vẫn chạy được nếu đã provision, nhưng server mới nên provision trước.

---

## Phase A — Máy operator: chuẩn bị validator mới

Chạy trong repo `blockchain-dock`, thư mục `blockchain-dockerize/docker-compose/chain-dpos`.

### A.1 + A.2 — Một lệnh (khuyến nghị)

```bash
make prepare-new-validator-local NODE_ID="${NODE_ID}"
```

`SEED_SERVER` lấy từ `envs/deploy.env`. Bỏ `NODE_ID` để script tự chọn `validator-N` tiếp theo (`validator-2`, `validator-3`, …).

Nếu peer bundle **đã có trong local repo** (`genesis/reserved-peers.txt` + `genesis/spec.json`), lệnh trên **tự bỏ qua** `pull-peer-config`. Hoặc dùng `SKIP_PULL=1` rõ ràng:

```bash
make prepare-new-validator-local SKIP_PULL=1 NODE_ID="${NODE_ID}"
make prepare-new-node TYPE=validator NODE_ID="${NODE_ID}"
```

Tương đương (khi cần pull từ seed):

1. `make pull-peer-config` — kéo `genesis/spec.json`, `reserved-peers.txt`, `contract-addresses.json`, enode seed
2. `make prepare-new-node TYPE=validator` — tạo keystore + `config.toml` + `reserved-peers.txt`

### A.1 Kéo peer bundle từ seed (chỉ khi thiếu hoặc enode đổi)

```bash
make pull-peer-config
```

Kéo về local:

- `genesis/spec.json` (phase-2, shared toàn mạng)
- `genesis/contract-addresses.json`
- `genesis/reserved-peers.txt` (enode seed)
- `genesis/validator-1.enode`, `genesis/peers/*.enode`

### A.2 Tạo keystore + config (tách riêng)

```bash
make prepare-new-node TYPE=validator NODE_ID="${NODE_ID}"
```

Script tạo (dưới `nodes/${NODE_ID}/`):

| File | Mô tả |
|------|--------|
| `keystore/UTC--*` | Private key validator |
| `node.pwd` | Password unlock account |
| `address` | Địa chỉ validator (dùng stake sau) |
| `config.toml` | OpenEthereum config |
| `reserved-peers.txt` | Enode seed (bootstrap) |

Ghi lại address:

```bash
cat "nodes/${NODE_ID}/address"
```

> **Lưu ý:** Không commit keystore / `node.pwd` lên git. Backup an toàn trước khi sync lên server.

---

## Phase B — Sync bundle lên server remote

```bash
make sync-new-validator SERVER=root@<IP_VALIDATOR_MOI> NODE_ID="${NODE_ID}"
```

Script `sync-new-validator.sh` chỉ đẩy **bundle tối thiểu** (không DApps):

| Đường dẫn remote | Nội dung |
|--------------------|----------|
| `chain-dpos/envs/` | `deploy.env`, `dpos.chain.env`, `images.env`, `openethereum.env`, netstats |
| `chain-dpos/nodes/<NODE_ID>/` | Config + keystore validator mới |
| `chain-dpos/genesis/` | spec, reserved-peers, contract-addresses |
| `chain-dpos/scripts/`, `templates/` | Scripts chạy node |
| `chain-dpos/overrides/<NODE_ID>.override.yml`, `compose-<NODE_ID>.yml` | Chỉ nếu đã generate trên local — **không** dùng stub trong repo |
| `services/` | Chỉ `compose-openethereum-node.yml`, `compose-netstats-api.yml` |

**Không có trên server validator mới:** `Makefile`, `make/`, `compose-dapps*`, `compose-validator-1.yml`, `traefik/`, `assets/`, `examples/`, `docker-compose/envs/`

Cấu trúc `chain-dpos/` sau sync:

```
chain-dpos/
├── compose-<NODE_ID>.yml      # sau ssh-new-validator-prepare (không dùng stub repo)
├── envs/
│   ├── deploy.env             # P2P_PUBLIC_IP = IP public server validator
│   └── <NODE_ID>.env          # sau prepare
├── genesis/
├── nodes/<NODE_ID>/
├── overrides/<NODE_ID>.override.yml
├── scripts/
└── templates/
```

### B.1 `P2P_PUBLIC_IP` trên server validator

`sync-new-validator` copy `envs/deploy.env` từ máy operator — file này thường có `P2P_PUBLIC_IP` trỏ **seed host**. Trên server validator mới phải sửa thành IP public của chính server đó **trước** `ssh-new-validator-prepare`:

```bash
VALIDATOR_IP=185.202.236.10   # IP public server validator mới
REMOTE_CHAIN=/opt/blockchain-gtbs/blockchain-dockerize/docker-compose/chain-dpos

ssh root@${VALIDATOR_IP} "sed -i 's/^P2P_PUBLIC_IP=.*/P2P_PUBLIC_IP=${VALIDATOR_IP}/' \
  ${REMOTE_CHAIN}/envs/deploy.env && grep P2P_PUBLIC_IP ${REMOTE_CHAIN}/envs/deploy.env"
```

Nếu chưa mở firewall P2P:

```bash
ssh root@${VALIDATOR_IP} "cd ${REMOTE_CHAIN} && \
  sudo OPEN_P2P_PORT=1 P2P_PORT=30300 ./scripts/remote/open-p2p-port.sh"
```

### Rsync thủ công (nếu không dùng make)

Từ máy operator (đã clone full `blockchain-dock`). Đặt biến shell cho host validator mới:

```bash
REMOTE_SERVER=root@<IP_VALIDATOR_MOI>
REMOTE_DIR=/opt/blockchain-gtbs   # khớp REMOTE_DEPLOY_DIR trong deploy.env

cd blockchain-dockerize/docker-compose/chain-dpos

CHAIN_ROOT="$(pwd)"
DOCK_ROOT="$(cd ../../.. && pwd)"
REMOTE_CHAIN="${REMOTE_DIR}/blockchain-dockerize/docker-compose/chain-dpos"

# Chuẩn bị thư mục trên server remote
ssh "${REMOTE_SERVER}" "sudo mkdir -p '${REMOTE_CHAIN}' && sudo chown -R \$(whoami):\$(whoami) '${REMOTE_DIR}'"

# Services + envs dùng chung
rsync -avz ../services/ "${REMOTE_SERVER}:${REMOTE_DIR}/blockchain-dockerize/docker-compose/services/"
rsync -avz ../envs/     "${REMOTE_SERVER}:${REMOTE_DIR}/blockchain-dockerize/docker-compose/envs/"

# chain-dpos: genesis + nodes/<NODE_ID>, bỏ data validator-1
rsync -avz --delete \
  --exclude 'nodes/validator-1/data/' \
  --exclude 'nodes/validator-1/keystore/' \
  --exclude 'nodes/rpc/data/' \
  --exclude 'data/' \
  --exclude '.git/' \
  "${CHAIN_ROOT}/" "${REMOTE_SERVER}:${REMOTE_CHAIN}/"

ssh "${REMOTE_SERVER}" "chmod +x '${REMOTE_CHAIN}/scripts/'*.sh '${REMOTE_CHAIN}/scripts/remote/'*.sh"
```

**Trên server remote cần có:**

- `genesis/spec.json`, `genesis/reserved-peers.txt`
- `nodes/${NODE_ID}/` (config, keystore, reserved-peers)
- `envs/deploy.env` — copy/sửa từ operator (cùng `NETWORK_*`, `DOCKERHUB_NAMESPACE`)

Copy `deploy.env` nếu chưa có trên server 2:

```bash
scp envs/deploy.env "${REMOTE_SERVER}:${REMOTE_CHAIN}/envs/deploy.env"
```

---

## Phase C — Server remote: prepare (render env + compose)

> **Từ máy operator (khuyến nghị):** `make ssh-new-validator-prepare SERVER=... NODE_ID=...`  
> Bước này **bắt buộc** trước `ssh-new-validator-up`.

```bash
make ssh-new-validator-prepare SERVER=root@<IP_VALIDATOR_MOI> NODE_ID="${NODE_ID}"
```

Hoặc trên server:

```bash
ssh "${REMOTE_SERVER}"
cd "${REMOTE_DIR}/blockchain-dockerize/docker-compose/chain-dpos"
NODE_ID="${NODE_ID}" ./scripts/remote/prepare-new-validator.sh
```

Script tạo:

- `envs/<NODE_ID>.env` — `VALIDATOR_ADDRESS`, `SPEC_PATH`, `OE_CONFIG_PATH`
- `overrides/<NODE_ID>.override.yml`
- `compose-<NODE_ID>.yml` — ghi đè stub trong repo (nếu có)

### C.1 Render env files (thủ công — thường không cần nếu đã chạy prepare)

Chỉnh `envs/deploy.env` trên server remote — **bắt buộc khớp** seed:

- `NETWORK_NAME`, `NETWORK_ID`, `NETWORK_TYPE`
- `DOCKERHUB_NAMESPACE`
- `P2P_PORT=30300`
- `P2P_PUBLIC_IP=<IP-public-server-remote>` (IP trong enode validator mới)
- `OPEN_P2P_PORT=true`

```bash
./scripts/render-envs.sh envs/deploy.env
```

### C.2 Tạo `envs/${NODE_ID}.env`

```bash
VALIDATOR_ADDRESS="$(tr '[:upper:]' '[:lower:]' < "nodes/${NODE_ID}/address")"
cat > "envs/${NODE_ID}.env" <<EOF
VALIDATOR_ADDRESS=${VALIDATOR_ADDRESS}
SPEC_PATH=./genesis/spec.json
OE_CONFIG_PATH=./nodes/${NODE_ID}/config.toml
EOF
```

---

## Phase D — Server remote: compose validator mới

`prepare-new-validator.sh` (phase C) tự generate compose qua `scripts/lib/new-validator-compose.sh`. **Không** chỉnh tay trừ khi debug.

File `compose-validator-2.yml` trong repo là **stub** (chỉ comment) — không dùng trực tiếp. Sau `ssh-new-validator-prepare`, server có compose thật:

```yaml
name: dpos-validator-2

include:
  - path:
      - ../services/compose-openethereum-node.yml
      - ../services/compose-netstats-api.yml
      - ./overrides/validator-2.override.yml
    env_file:
      - ./envs/dpos.chain.env
      - ./envs/images.env
      - ./envs/netstats-dashboard.env
      - ./envs/netstats-api.env
```

Container names: `dpos-<NETWORK_TYPE>-<NODE_ID>` — ví dụ mainnet: `dpos-mainnet-validator-2`, `dpos-mainnet-netstats-validator-2`.

> Validator mới **không** chạy `validator-app` (consensus bot). Chỉ seed host chạy `validator-app` sau transition.

<details>
<summary>Chi tiết override (tham khảo — prepare tự tạo)</summary>

### D.1 `overrides/${NODE_ID}.override.yml`

```yaml
services:
  openethereum:
    container_name: 'dpos-${NETWORK_TYPE:-testnet}-${NODE_ID}'
    env_file:
      - ../chain-dpos/envs/openethereum.env
      - ../chain-dpos/envs/${NODE_ID}.env
    environment:
      OE_CONFIG_PATH: /app/config/config.toml
    volumes: !override
      - ../chain-dpos/genesis/spec.json:/app/genesis/spec.json:ro
      - ../chain-dpos/nodes/${NODE_ID}/config.toml:/app/config/config.toml:ro
      - ../chain-dpos/nodes/${NODE_ID}/keystore:/app/data/keys/${NETWORK_NAME}
      - ../chain-dpos/nodes/${NODE_ID}/node.pwd:/app/secrets/node.pwd:ro
      - ../chain-dpos/nodes/${NODE_ID}/reserved-peers.txt:/app/config/reserved-peers.txt:ro
      - ../chain-dpos/nodes/${NODE_ID}/data:/app/data
    ports: !override
      - "127.0.0.1:8545:8545"
      - "30300:30300"
      - "30300:30300/udp"
  netstats-api:
    container_name: 'dpos-${NETWORK_TYPE:-testnet}-netstats-${NODE_ID}'
    depends_on:
      - openethereum
    env_file:
      - ../chain-dpos/envs/netstats-dashboard.env
      - ../chain-dpos/envs/netstats-api.env
    environment:
      INSTANCE_NAME: ${NODE_ID}
      RPC_HOST: openethereum
```

### D.2 `compose-${NODE_ID}.yml`

```yaml
name: dpos-${NODE_ID}

include:
  - path:
      - ../services/compose-openethereum-node.yml
      - ../services/compose-netstats-api.yml
      - ./overrides/${NODE_ID}.override.yml
    env_file:
      - ./envs/dpos.chain.env
      - ./envs/images.env
      - ./envs/netstats-dashboard.env
      - ./envs/netstats-api.env
```

</details>

---

## Phase E — Server remote: start node

**Từ máy operator** (sau `ssh-new-validator-prepare`):

```bash
make ssh-new-validator-up SERVER=root@<IP_VALIDATOR_MOI> NODE_ID="${NODE_ID}"
```

Hoặc trên server:

```bash
cd "${REMOTE_DIR}/blockchain-dockerize/docker-compose/chain-dpos"
NODE_ID="${NODE_ID}" ./scripts/remote/new-validator-up.sh
```

> `new-validator-up.sh` chỉ tự chạy prepare khi **chưa có** `compose-<NODE_ID>.yml`. Nếu stub đã được sync lên server, prepare bị bỏ qua → lỗi `no service selected`. Luôn chạy `ssh-new-validator-prepare` trước.

Mở firewall P2P (nếu chưa provision với `OPEN_P2P_PORT=1`):

```bash
sudo OPEN_P2P_PORT=1 P2P_PORT=30300 ./scripts/remote/open-p2p-port.sh
```

Kiểm tra node sync:

```bash
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://127.0.0.1:8545 | jq .

docker logs -f "dpos-mainnet-${NODE_ID}"   # hoặc dpos-testnet-${NODE_ID} nếu testnet
docker logs "dpos-mainnet-${NODE_ID}" 2>&1 | grep peers | tail -1
```

Block number phải tăng và tiến về gần block trên seed. Log kỳ vọng: `1/25 peers` trở lên sau khi seed đã `add-peer-enode`.

---

## Phase F — Lấy enode public của validator mới

Chạy trên **server remote** (đợi container ready ~15s):

```bash
NODE_ID=validator-2
NETWORK_TYPE=mainnet   # hoặc testnet — khớp envs/dpos.chain.env

# Cách 1 (khuyến nghị): docker logs — RPC parity_nodeInfo thường trả null
RAW_ENODE="$(docker logs "dpos-${NETWORK_TYPE}-${NODE_ID}" 2>&1 | grep -Eo 'enode://[^ ]+' | head -1)"
echo "${RAW_ENODE}"

# Cách 2: RPC (có thể null tùy RPC namespace)
# ENODE="$(curl -s -X POST -H 'Content-Type: application/json' \
#   --data '{"jsonrpc":"2.0","method":"parity_nodeInfo","params":[],"id":1}' \
#   http://127.0.0.1:8545 | jq -r '.result.enode')"
```

Enode **phải** dùng IP public server remote. Log thường ra IP Docker nội bộ (`172.x.x.x`) — thay bằng IP public:

```bash
VALIDATOR_IP=185.202.236.10
NODE_KEY="${RAW_ENODE#enode://}"          # bỏ prefix
NODE_KEY="${NODE_KEY%%@*}"                # lấy phần key (trước @)
ENODE_NEW="enode://${NODE_KEY}@${VALIDATOR_IP}:30300"
echo "${ENODE_NEW}"
```

Lưu `ENODE_NEW` — dùng ở phase G.

---

## Phase G — Seed host: đăng ký peer + restart

SSH vào **seed host** (server 1):

```bash
cd "${REMOTE_DIR}/blockchain-dockerize/docker-compose/chain-dpos"

./scripts/add-peer-enode.sh \
  "${ENODE_NEW}" \
  --peer-id "${NODE_ID}"
```

Script sẽ:

1. Append enode vào `genesis/reserved-peers.txt`
2. Ghi `genesis/peers/${NODE_ID}.enode`
3. Sync sang `nodes/validator-1/reserved-peers.txt` và `nodes/rpc/reserved-peers.txt`

Kiểm tra:

```bash
cat genesis/reserved-peers.txt
# Kỳ vọng thêm 1 dòng enode validator mới
```

Restart validator-1 để load peers mới:

```bash
docker compose -f compose-validator-1.yml restart openethereum
```

---

## Phase H — Xác nhận peering

**Cách nhanh — docker logs** (RPC `parity_nodeInfo` có thể trả `null`):

```bash
# Seed
docker logs dpos-mainnet-validator-1 2>&1 | grep peers | tail -1

# Validator mới
docker logs dpos-mainnet-validator-2 2>&1 | grep peers | tail -1
```

Kỳ vọng: `1/25 peers` trở lên trên cả hai node sau phase G.

**RPC** (nếu namespace hỗ trợ):

```bash
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"parity_nodeInfo","params":[],"id":1}' \
  http://127.0.0.1:8545 | jq '.result.numPeers'
```

So sánh block gần bằng nhau:

```bash
# Seed vs validator mới
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://127.0.0.1:8545 | jq -r .result
```

Netstats (nếu đã deploy): seed và validator mới hiện trên dashboard.

---

## Stake (làm thủ công sau)

Sau khi peering ổn, fund wallet `nodes/${NODE_ID}/address` và stake `MIN_STAKE_TOKENS` (mặc định `100000` token) qua Consensus / StakingVault.

Validator xuất hiện trong `getValidators()` sau cycle consensus tiếp theo — **không** phụ thuộc bước `add-peer-enode`.

Xem thêm: [dpos-testnet.md](./dpos-testnet.md), [custom-staking-gtbs.md](./custom-staking-gtbs.md).

---

## Tạo lại validator từ đầu (clean redeploy)

Khi cần xóa sạch server validator và deploy lại (đổi `NODE_ID`, sửa lỗi cấu hình, v.v.):

**Trên server validator** (ví dụ `185.202.236.10`):

```bash
# Dừng và xóa containers
docker stop dpos-mainnet-validator-2 dpos-mainnet-netstats-validator-2 2>/dev/null || true
docker rm -f dpos-mainnet-validator-2 dpos-mainnet-netstats-validator-2 2>/dev/null || true

# Xóa images (tùy chọn — pull lại khi up)
docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | \
  grep -E 'blockchain-dock|openethereum|netstats' | awk '{print $2}' | \
  xargs -r docker rmi -f 2>/dev/null || true

# Xóa toàn bộ thư mục deploy
rm -rf /opt/blockchain-gtbs
```

**Từ máy operator** — chạy lại luồng make gọn ở đầu doc (phase A → B → C → E → G).

> Nếu giữ keystore cũ: `prepare-new-validator-local` idempotent (không tạo key mới nếu đã có). Muốn key mới: `make prepare-new-node TYPE=validator NODE_ID=validator-2 FORCE_KEYS=1`.

---

## Troubleshooting

| Triệu chứng | Nguyên nhân thường gặp | Cách xử lý |
|-------------|------------------------|------------|
| `no service selected` khi `compose up` | Stub `compose-<NODE_ID>.yml` đã sync lên server, prepare bị skip | `make ssh-new-validator-prepare` rồi `ssh-new-validator-up` lại |
| `numPeers = 0` trên cả hai node | Enode sai IP / firewall | Kiểm tra `P2P_PUBLIC_IP`, `ufw status`, enode có `@<public-ip>:30300` |
| Enode trong log là `172.x.x.x` | IP Docker nội bộ | Thay bằng IP public khi `add-peer-enode` (phase F) |
| Chỉ validator mới thấy peer, seed không | Chưa `add-peer-enode` hoặc chưa restart seed | Chạy phase G, restart `openethereum` seed |
| Block không sync trên validator mới | Sai `spec.json` hoặc chain ID | So sánh `genesis/spec.json` với seed |
| `parity_nodeInfo` trả `null` | RPC namespace không expose parity | Dùng `docker logs … \| grep peers` thay RPC |
| Port 30300 conflict | Service khác chiếm port | `ss -ulnp \| grep 30300` |
| NODE_ID không nhất quán (`2` vs `validator-2`) | Deploy cũ dùng tên số | Luôn dùng `validator-N`; clean redeploy nếu cần |

### Lệnh hữu ích

```bash
# Seed: refresh enode (nếu IP seed đổi)
./scripts/export-peer-config.sh

# Operator: kéo lại bundle (SEED_SERVER trong deploy.env)
make pull-peer-config

# Operator: prepare / start / logs trên server remote
make ssh-new-validator-prepare SERVER=root@host NODE_ID=validator-2
make ssh-new-validator-up SERVER=root@host NODE_ID=validator-2
make ssh-new-validator-logs SERVER=root@host NODE_ID=validator-2
make ssh-new-validator-down SERVER=root@host NODE_ID=validator-2
```

---

## Checklist

- [ ] **Phase 0** Operator: `deploy.env` có `SEED_SERVER`, `REMOTE_DEPLOY_DIR` khớp seed
- [ ] **Phase 0** Server remote: `make setup-ssh` + `make provision-remote OPEN_P2P_PORT=1`
- [ ] `NODE_ID=validator-N` (không dùng số thuần `2`)
- [ ] `make prepare-new-validator-local NODE_ID=...` → ghi `nodes/<NODE_ID>/address`
- [ ] `make sync-new-validator SERVER=... NODE_ID=...`
- [ ] Sửa `P2P_PUBLIC_IP` trên server validator = IP public server đó
- [ ] `make ssh-new-validator-prepare SERVER=... NODE_ID=...` (**bắt buộc**)
- [ ] `make ssh-new-validator-up SERVER=... NODE_ID=...`
- [ ] Block sync gần bằng seed (`eth_blockNumber`)
- [ ] Lấy enode public (docker logs + thay IP Docker → IP public)
- [ ] Seed: `add-peer-enode.sh --peer-id <NODE_ID>` + restart validator-1
- [ ] `grep peers` trong docker logs: `1/25 peers` trở lên trên cả hai node
- [ ] *(Sau)* Stake `MIN_STAKE` cho address validator mới
