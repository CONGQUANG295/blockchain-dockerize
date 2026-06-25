# Setup new validator trên server remote

Hướng dẫn thêm **validator mới** (non-seed) vào mạng DPoS đã chạy trên **seed host** (validator-1).

**Giả định:**

- Seed host đã bootstrap xong: chain chạy, `export-peer-config.sh` đã chạy, P2P port `30300` mở public.
- Chain **không dùng bootnode** — peering qua static enode trong `reserved-peers.txt`.
- **Stake** (`MIN_STAKE_TOKENS`) làm thủ công sau — không nằm trong guide này.

**Biến mẫu** (thay theo môi trường thực tế):

| Biến | Ví dụ | Ghi chú |
|------|--------|---------|
| `SEED_SERVER` | `root@91.229.245.75` | Host chạy validator-1 |
| `REMOTE_SERVER` | `root@203.0.113.50` | Host chạy validator mới |
| `REMOTE_DIR` | `/opt/blockchain-dock` | Thư mục deploy trên server |
| `NODE_ID` | `validator-2` | Tên thư mục `nodes/<NODE_ID>/` (auto nếu bỏ qua) |

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
| **`make prepare-new-validator-local SEED_SERVER=...`** | **Kéo peer bundle từ seed + tạo `nodes/<NODE_ID>/`** |
| `make pull-peer-config SERVER=...` | Chỉ kéo bundle (không tạo keystore) |
| `make prepare-new-node TYPE=validator [NODE_ID=...]` | Chỉ tạo keystore (cần bundle sẵn; auto `validator-N` nếu bỏ `NODE_ID`) |
| **`make sync-new-validator SERVER=... NODE_ID=...`** | **Rsync node validator mới lên server remote** |
| **`make ssh-new-validator-up SERVER=... NODE_ID=...`** | **SSH: prepare + docker compose up trên server** |
| `make ssh-new-validator-prepare SERVER=... NODE_ID=...` | SSH: chỉ render env + tạo compose trên server |
| `make ssh-new-validator-down / ssh-new-validator-logs` | SSH: down / follow logs |
| `make sync SERVER=...` | Rsync cho **seed deploy** — không dùng cho validator mới |

**Luồng make gọn (local):**

```bash
cd blockchain-dockerize/docker-compose/chain-dpos

# Phase 0 — một lần
make init && $EDITOR envs/deploy.env && make render
make setup-ssh SERVER="${REMOTE_SERVER}"
make provision-remote SERVER="${REMOTE_SERVER}" REMOTE_DIR="${REMOTE_DIR}" OPEN_P2P_PORT=1

# Phase A — chuẩn bị validator mới trên local (1 lệnh)
make prepare-new-validator-local \
  SEED_SERVER="${SEED_SERVER}" \
  REMOTE_DIR="${REMOTE_DIR}" \
  NODE_ID="${NODE_ID}"

# Ghi NODE_ID thực tế script vừa tạo (nếu không truyền — thường validator-2, validator-3, …)
NODE_ID="${NODE_ID:-$(ls -d nodes/validator-* 2>/dev/null | sed 's|.*/||' | sort -t- -k2 -n | tail -1)}"

# Phase B — đẩy lên server remote
make sync-new-validator SERVER="${REMOTE_SERVER}" NODE_ID="${NODE_ID}" REMOTE_DIR="${REMOTE_DIR}"

# Phase C+E — start validator trên server (từ máy operator)
make ssh-new-validator-up \
  SERVER="${REMOTE_SERVER}" \
  NODE_ID="${NODE_ID}" \
  REMOTE_DIR="${REMOTE_DIR}"
```

> `ssh-new-validator-up` tự chạy `prepare-new-validator.sh` trên server (render env + tạo `compose-<NODE_ID>.yml`) nếu chưa có.

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
  render envs + envs/<NODE_ID>.env
  → compose up openethereum
  → mở P2P 30300
  → lấy enode public

[Seed host]
  add-peer-enode.sh <enode> --peer-id <NODE_ID>
  → restart validator-1
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
| `REMOTE_DEPLOY_DIR` | Thường `/opt/blockchain-dock` |
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

make setup-ssh SERVER="${REMOTE_SERVER}"
# hoặc: ./scripts/local/setup-ssh.sh "${REMOTE_SERVER}"
```

**Bước 2 — Cài Docker, Compose, Node, jq, rsync, tạo `${REMOTE_DIR}`:**

```bash
make provision-remote \
  SERVER="${REMOTE_SERVER}" \
  REMOTE_DIR="${REMOTE_DIR}" \
  OPEN_P2P_PORT=1
```

`provision-remote` chạy `scripts/remote/provision-server.sh` trên server remote và cài:

- Docker CE + Compose plugin v2
- Node.js 18+, `jq`, `curl`, `rsync`, `git`, `make`
- Thư mục deploy `${REMOTE_DIR}` (owner = user SSH)
- *(Tuỳ chọn)* Mở ufw port `30300` TCP/UDP khi `OPEN_P2P_PORT=1`

Kiểm tra trên server remote:

```bash
ssh "${REMOTE_SERVER}" "docker --version && docker compose version && jq --version && node -v"
```
```

> **Thứ tự:** Phase 0.2 (provision) **trước** Phase B (rsync). Doc cũ đặt provision ở Phase C — vẫn chạy được nếu đã provision, nhưng server mới nên provision trước.

---

## Phase A — Máy operator: chuẩn bị validator mới

Chạy trong repo `blockchain-dock`, thư mục `blockchain-dockerize/docker-compose/chain-dpos`.

### A.1 + A.2 — Một lệnh (khuyến nghị)

```bash
make prepare-new-validator-local \
  SEED_SERVER="${SEED_SERVER}" \
  REMOTE_DIR="${REMOTE_DIR}" \
  NODE_ID="${NODE_ID}"
```

Bỏ `NODE_ID` để script tự chọn `validator-N` tiếp theo (`validator-2`, `validator-3`, …).

Tương đương:

1. `make pull-peer-config` — kéo `genesis/spec.json`, `reserved-peers.txt`, `contract-addresses.json`, enode seed
2. `make prepare-new-node TYPE=validator` — tạo keystore + `config.toml` + `reserved-peers.txt`

### A.1 Kéo peer bundle từ seed (tách riêng)

```bash
make pull-peer-config \
  SERVER="${SEED_SERVER}" \
  REMOTE_DIR="${REMOTE_DIR}"
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
make sync-new-validator \
  SERVER="${REMOTE_SERVER}" \
  NODE_ID="${NODE_ID}" \
  REMOTE_DIR="${REMOTE_DIR}"
```

Script `sync-new-validator.sh` chỉ đẩy **bundle tối thiểu** (không DApps):

| Đường dẫn remote | Nội dung |
|--------------------|----------|
| `chain-dpos/envs/` | `deploy.env`, `dpos.chain.env`, `images.env`, `openethereum.env`, netstats |
| `chain-dpos/nodes/<NODE_ID>/` | Config + keystore validator mới |
| `chain-dpos/genesis/` | spec, reserved-peers, contract-addresses |
| `chain-dpos/scripts/`, `templates/` | Scripts chạy node |
| `chain-dpos/overrides/<NODE_ID>.override.yml`, `compose-<NODE_ID>.yml` | Nếu đã generate |
| `services/` | Chỉ `compose-openethereum-node.yml`, `compose-netstats-api.yml` |

**Không có trên server validator mới:** `Makefile`, `make/`, `compose-dapps*`, `compose-validator-1.yml`, `traefik/`, `assets/`, `examples/`, `docker-compose/envs/`

Cấu trúc `chain-dpos/` sau sync:

```
chain-dpos/
├── compose-<NODE_ID>.yml      # sau prepare / ssh-new-validator-up
├── envs/
├── genesis/
├── nodes/<NODE_ID>/
├── overrides/<NODE_ID>.override.yml
├── scripts/
└── templates/
```

### Rsync thủ công (nếu không dùng make)

Từ máy operator (đã clone full `blockchain-dock`):

```bash
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

## Phase C — Server remote: cấu hình env

> **Từ máy operator (khuyến nghị):** `make ssh-new-validator-prepare SERVER=... NODE_ID=...`  
> Hoặc `make ssh-new-validator-up` (gồm cả prepare + start).

```bash
ssh "${REMOTE_SERVER}"
cd "${REMOTE_DIR}/blockchain-dockerize/docker-compose/chain-dpos"
NODE_ID="${NODE_ID}" ./scripts/remote/prepare-new-validator.sh
```

### C.1 Render env files (thủ công)

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

Compose theo `NODE_ID` chưa có sẵn trong repo (stub). Tạo override trước khi start — ví dụ `NODE_ID=validator-2`:

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

> Validator mới **không** chạy `validator-app` (consensus bot). Chỉ seed host chạy `validator-app` sau transition.

---

## Phase E — Server remote: start node

**Từ máy operator:**

```bash
make ssh-new-validator-up \
  SERVER="${REMOTE_SERVER}" \
  NODE_ID="${NODE_ID}" \
  REMOTE_DIR="${REMOTE_DIR}"
```

```bash
cd "${REMOTE_DIR}/blockchain-dockerize/docker-compose/chain-dpos"
NODE_ID="${NODE_ID}" ./scripts/remote/new-validator-up.sh
```

Mở firewall P2P (nếu chưa provision với `OPEN_P2P_PORT=1`):

```bash
sudo OPEN_P2P_PORT=1 P2P_PORT=30300 ./scripts/remote/open-p2p-port.sh
```

Kiểm tra node sync:

```bash
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://127.0.0.1:8545 | jq .

docker logs -f "dpos-testnet-${NODE_ID}"
```

Block number phải tăng và tiến về gần block trên seed.

---

## Phase F — Lấy enode public của validator mới

Chạy trên **server remote**:

```bash
# Cách 1: RPC
ENODE="$(curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"parity_nodeInfo","params":[],"id":1}' \
  http://127.0.0.1:8545 | jq -r '.result.enode')"

# Cách 2: docker logs
# ENODE="$(docker logs "dpos-testnet-${NODE_ID}" 2>&1 | grep -Eo 'enode://[^ ]+' | head -1)"

echo "${ENODE}"
```

Enode **phải** dùng IP public server remote. Nếu ra `127.0.0.1` hoặc IP Docker, sửa tay:

```bash
# Thay <NODE_KEY> và <IP_PUBLIC> từ output trên
ENODE_NEW='enode://<NODE_KEY>@<IP_PUBLIC>:30300'
echo "${ENODE_NEW}"
```

Lưu enode — dùng ở phase G.

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

**Trên seed host:**

```bash
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"parity_nodeInfo","params":[],"id":1}' \
  http://127.0.0.1:8545 | jq '.result.numPeers'
```

**Trên server remote:**

```bash
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"parity_nodeInfo","params":[],"id":1}' \
  http://127.0.0.1:8545 | jq '.result.numPeers'
```

Cả seed và validator mới: `numPeers >= 1`.

Chi tiết peers:

```bash
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"parity_peers","params":[],"id":1}' \
  http://127.0.0.1:8545 | jq '.result[].id'
```

Netstats (nếu đã deploy): seed và validator mới hiện trên dashboard.

---

## Stake (làm thủ công sau)

Sau khi peering ổn, fund wallet `nodes/${NODE_ID}/address` và stake `MIN_STAKE_TOKENS` (mặc định `100000` token) qua Consensus / StakingVault.

Validator xuất hiện trong `getValidators()` sau cycle consensus tiếp theo — **không** phụ thuộc bước `add-peer-enode`.

Xem thêm: [dpos-testnet.md](./dpos-testnet.md), [custom-staking-gtbs.md](./custom-staking-gtbs.md).

---

## Troubleshooting

| Triệu chứng | Nguyên nhân thường gặp | Cách xử lý |
|-------------|------------------------|------------|
| `numPeers = 0` trên cả hai node | Enode sai IP / firewall | Kiểm tra `P2P_PUBLIC_IP`, `ufw status`, enode có `@<public-ip>:30300` |
| Chỉ validator mới thấy peer, seed không | Chưa `add-peer-enode` hoặc chưa restart seed | Chạy phase G, restart `openethereum` seed |
| Block không sync trên validator mới | Sai `spec.json` hoặc chain ID | So sánh `genesis/spec.json` với seed |
| RPC `parity_nodeInfo` lỗi | Container chưa ready | `docker logs dpos-testnet-${NODE_ID}` |
| Port 30300 conflict | Service khác chiếm port | `ss -ulnp \| grep 30300` |

### Lệnh hữu ích

```bash
# Seed: refresh enode (nếu IP seed đổi)
./scripts/export-peer-config.sh

# Operator: kéo lại bundle
make pull-peer-config SERVER="${SEED_SERVER}" REMOTE_DIR="${REMOTE_DIR}"

# Operator: start / logs trên server remote
make ssh-new-validator-up SERVER=root@host NODE_ID=2 REMOTE_DIR=/opt/blockchain-gtbs
make ssh-new-validator-logs SERVER=root@host NODE_ID=2 REMOTE_DIR=/opt/blockchain-gtbs
make ssh-new-validator-down SERVER=root@host NODE_ID=2 REMOTE_DIR=/opt/blockchain-gtbs
```

---

## Checklist

- [ ] **Phase 0** Operator: `make check-deps`, `deploy.env` khớp seed
- [ ] **Phase 0** Server remote: `make setup-ssh` + `make provision-remote OPEN_P2P_PORT=1`
- [ ] `make prepare-new-validator-local SEED_SERVER=...` → ghi `NODE_ID`
- [ ] `make sync-new-validator SERVER=... NODE_ID=...`
- [ ] `make ssh-new-validator-up SERVER=... NODE_ID=...` (đảm bảo `P2P_PUBLIC_IP` trong `deploy.env` trên server)
- [ ] Block sync gần bằng seed
- [ ] Lấy enode public
- [ ] Seed: `add-peer-enode.sh` + restart validator-1
- [ ] `numPeers >= 1` trên cả hai node
- [ ] *(Sau)* Stake `MIN_STAKE` cho address validator mới
