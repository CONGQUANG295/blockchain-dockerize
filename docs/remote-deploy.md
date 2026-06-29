# Remote deploy (Docker Hub + local prepare)

Triển khai chain DPoS lên server **không clone git trên server**. Operator chuẩn bị trên máy local; server chỉ cài môi trường, `docker pull`, và `docker compose up`.

> **Deploy seed node từ đầu:** xem [deploy-seed-node.md](./deploy-seed-node.md) — hướng dẫn end-to-end cho validator-1 (seed).

> **Makefile:** Các bước dưới có thể chạy qua `make` từ root `blockchain-dock/`. Xem [docs/makefile.md](../../docs/makefile.md).

## Luồng tổng quan

```mermaid
flowchart LR
  subgraph local["Máy operator (clone blockchain-dock)"]
    P["prepare-deploy.sh\nrender + genesis"]
    S["sync-to-server.sh\nrsync bundle"]
    P --> S
  end

  subgraph server["Server đích"]
    PR["provision-server.sh\nDocker + Node + jq"]
    V["deploy-validator.sh\nbootstrap B–F + validator-app"]
    D["deploy-dapps.sh\nnetstats + docs + Traefik"]
    PR --> V --> D
  end

  S -->|rsync| server
  DH[(Docker Hub)] -->|docker pull| server
```

| Vai trò | Việc làm |
|---------|----------|
| **Local** | Clone repo, sửa `deploy.env`, genesis (phase A), rsync bundle |
| **Docker Hub** | Images `DOCKERHUB_NAMESPACE/blockchain-dock-*` (CI hoặc `build-and-push.sh --push`) |
| **Server** | Cài Docker một lần; chạy deploy validator / dapps theo nhu cầu |

---

## Bước 1 — Build & push images (một lần / mỗi release)

Trên máy có Docker (hoặc CI):

```bash
cd blockchain-docker-base
docker login
./scripts/build-and-push.sh --push --namespace <dockerhub-user>
```

Hoặc từ root monorepo:

```bash
make build login
make build push DOCKERHUB_NAMESPACE=<dockerhub-user>
```

Chi tiết: [`blockchain-docker-base/README.md`](../../blockchain-docker-base/README.md).

---

## Bước 2 — Chuẩn bị trên máy operator

```bash
cd blockchain-dockerize/docker-compose/chain-dpos

cp envs/deploy.env.example envs/deploy.env
# Sửa: DOCKERHUB_NAMESPACE, NETWORK_*, PREMINE_ADDRESS, domains (--with-traefik)
# SSH targets trong deploy.env:
#   REMOTE_DEPLOY_DIR, SEED_SERVER, EXPLORER_SERVER, DAPPS_SERVER
# Lệnh đa-server: make sync SEED=1 | EXPLORER=1 | DAPPS=1 | SERVER=user@host

./scripts/local/prepare-deploy.sh --with-traefik
```

Makefile:

```bash
make dpos init
# chỉnh envs/deploy.env
make dpos prepare-remote WITH_TRAEFIK=1
```

Script này chạy `render-envs.sh` + `prepare-genesis.sh` (phase A: keystore, spec phase-1).

---

## Bước 2b — SSH key (một lần, khuyến nghị)

Các lệnh `provision-remote`, `sync`, `ssh-deploy-*` dùng **SSH key** — không hỏi password lặp lại.

```bash
# Tạo key nếu chưa có
ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)"

# Copy key lên server (nhập password server một lần duy nhất)
make dpos setup-ssh SEED=1
# hoặc: make dpos setup-ssh EXPLORER=1 | DAPPS=1 | SERVER=ubuntu@your-server
```

Hoặc: `ssh-copy-id ubuntu@your-server`

Kiểm tra:

```bash
ssh -o BatchMode=yes ubuntu@your-server "echo ok"
```

> Dùng user deploy thường (`ubuntu@`), không khuyến nghị `root@` cho vận hành hàng ngày.

---

## Bước 3 — Provision server (một lần)

**Từ máy operator:**

```bash
./scripts/local/provision-remote.sh ubuntu@your-server
```

Makefile: `make dpos provision-remote SEED=1` (hoặc `EXPLORER=1` | `DAPPS=1` | `SERVER=...`)

**Hoặc trên server:**

```bash
sudo ./scripts/remote/provision-server.sh
```

Cài: Docker 20.10+, Compose v2, Node 18+, `jq`, `curl`, `rsync`.

Cấu hình log Docker (`/etc/docker/daemon.json`): **tối đa 3 file × 10MB** mỗi container (`json-file` driver). Tuỳ chỉnh khi provision:

```bash
sudo DOCKER_LOG_MAX_SIZE=10m DOCKER_LOG_MAX_FILE=3 ./scripts/remote/provision-server.sh
```

Container đã chạy trước khi đổi daemon cần recreate để áp dụng log mới: `docker compose up -d --force-recreate`.

---

## Bước 4 — Sync bundle lên server

```bash
./scripts/local/sync-to-server.sh ubuntu@your-server
# Tuỳ chọn custom path:
# ./scripts/local/sync-to-server.sh ubuntu@your-server /opt/blockchain-dock
```

Makefile:

```bash
make dpos sync SEED=1
# Explorer / DApps / host khác:
make dpos sync EXPLORER=1
make dpos sync DAPPS=1
make dpos sync SERVER=ubuntu@your-server REMOTE_DIR=/opt/blockchain-dock
```

> `REMOTE_DIR` mặc định từ `REMOTE_DEPLOY_DIR` trong `deploy.env`. `sync` **không** tự chọn server — dùng cờ `SEED=1` / `EXPLORER=1` / `DAPPS=1` hoặc `SERVER=`.

Đồng bộ:

- `blockchain-dockerize/docker-compose/chain-dpos/` (genesis, keystore, env, compose, scripts)
- `blockchain-dockerize/docker-compose/services/` (shared compose fragments cho validator/DApps)
- `blockchain-dockerize/docker-compose/envs/` (paths `../envs/*.env` trong services compose)
- `blockchain-docker-base/resources/dpos-contracts/` (script bootstrap trên server)

**Không** sync `nodes/*/data/`, `data/` (DB tạo mới trên server).

---

## Bước 5 — Deploy trên server

SSH vào server:

```bash
cd /opt/blockchain-dock/blockchain-dockerize/docker-compose/chain-dpos

# Validator: bootstrap chain (B–F) + validator-app
./scripts/remote/deploy-validator.sh --with-traefik

# DApps: RPC + Blockscout v11 + Traefik (+ faucet nếu testnet)
./scripts/remote/deploy-dapps.sh
```

Makefile (từ operator, qua SSH):

```bash
make dpos ssh-deploy-validator WITH_TRAEFIK=1   # mặc định SEED_SERVER trong deploy.env
make dpos ssh-deploy-dapps SERVER=ubuntu@your-server
```

Hoặc trên server sau khi SSH:

```bash
make deploy-remote-validator WITH_TRAEFIK=1
make deploy-remote-dapps
```

### Chỉ validator (không DApps)

```bash
./scripts/remote/deploy-validator.sh
```

### Chỉ DApps (chain đã chạy)

Từ máy operator (khuyến nghị):

```bash
make prepare-new-node TYPE=rpc
make render WITH_TRAEFIK=1
make sync DAPPS=1
make sync-peer-bundle DAPPS=1
make ssh-deploy-dapps
```

Redeploy sạch RPC data:

```bash
make ssh-clean-dapps PRUNE_IMAGES=1
make sync-peer-bundle DAPPS=1
make prepare-new-node TYPE=rpc && make sync DAPPS=1
make ssh-deploy-dapps SKIP_HEALTH=1
```

Hoặc trên server sau khi SSH:

```bash
./scripts/remote/deploy-dapps.sh
```

### Khởi động lại validator (đã bootstrap)

```bash
./scripts/remote/deploy-validator.sh --skip-bootstrap
```

---

## Capture peer bundle (một lần sau seed deploy)

Sau khi `deploy-validator.sh` thành công trên server seed, script tự chạy `export-peer-config.sh` (tạo enode + `reserved-peers.txt` trên server).

**Trên máy operator**, kéo peer bundle về local repo **một lần** và commit:

```bash
cd blockchain-dockerize/docker-compose/chain-dpos

# Cấu hình SEED_SERVER + REMOTE_DEPLOY_DIR trong envs/deploy.env trước
make pull-peer-config

git add genesis/reserved-peers.txt \
        genesis/validator-1.enode \
        genesis/peers/ \
        genesis/contract-addresses.json
git commit -m "chore: capture peer bundle after seed validator deploy"
```

Artifact này dùng cho mọi node non-seed sau này (explorer RPC, validator mới) — **không** cần `pull-peer-config` lại trừ khi seed đổi IP hoặc enode thay đổi.

| File | Mục đích |
|------|----------|
| `genesis/reserved-peers.txt` | Enode bootstrap cho RPC / validator mới |
| `genesis/validator-1.enode` | Enode seed validator |
| `genesis/peers/seed.enode` | Bản sao enode seed |
| `genesis/contract-addresses.json` | Địa chỉ contracts sau deploy |

Đẩy peer bundle lên server non-seed (explorer, validator mới):

```bash
make sync-peer-bundle EXPLORER=1
# hoặc: make sync-peer-bundle SERVER=ubuntu@host
```

`sync-to-server.sh` cố ý **không** sync các file trên (tránh ghi đè enode trên seed server).

---

## DNS & firewall

Trước `deploy-dapps.sh` với Traefik:

1. Trỏ A record các domain trong `deploy.env` về IP server
2. Mở port **80**, **443** (và **30300** nếu cần P2P public)

---

## Scripts tham chiếu

| Script | Chạy ở | Mục đích | Make (từ repo root) |
|--------|--------|----------|---------------------|
| `scripts/local/prepare-deploy.sh` | Operator | Render env + genesis | `make dpos prepare-remote WITH_TRAEFIK=1` |
| `scripts/local/sync-to-server.sh` | Operator | Rsync bundle | `make dpos sync SEED=1` \| `EXPLORER=1` \| `SERVER=...` |
| `scripts/local/sync-peer-bundle.sh` | Operator | Push peer bundle | `make dpos sync-peer-bundle EXPLORER=1` |
| `scripts/local/pull-peer-config.sh` | Operator | Kéo peer bundle từ seed (một lần) | `make dpos pull-peer-config` |
| `scripts/local/provision-remote.sh` | Operator | SSH provision server | `make dpos provision-remote` |
| `scripts/remote/provision-server.sh` | Server | Cài Docker + tools | _(chạy trực tiếp trên server)_ |
| `scripts/remote/deploy-validator.sh` | Server | Chain + validator-app | `make dpos ssh-deploy-validator` hoặc `make deploy-remote-validator` trên server |
| `scripts/remote/deploy-dapps.sh` | Server DApps | RPC archive + netstats-dashboard, docs, Traefik | `make ssh-deploy-dapps` (DAPPS_SERVER) |
| `scripts/remote/deploy-explorer.sh` | Server | Explorer only (no netstats) | `make ssh-deploy-explorer` |
| `scripts/remote/clean-explorer.sh` | Server | Wipe explorer RPC + Blockscout DB | `make ssh-clean-explorer EXPLORER=1` |
| `scripts/remote/clean-dapps.sh` | Server DApps | Wipe DApps RPC chain data | `make ssh-clean-dapps DAPPS=1` |
| `scripts/build-and-push.sh --push` | Operator / CI | Push images Docker Hub | `make build push DOCKERHUB_NAMESPACE=...` |

---

## Liên quan

- [deploy-explorer-server-3.md](./deploy-explorer-server-3.md) — Deploy Explorer lên server riêng (tách khỏi validator)
- [validator-1-custom-contracts.md](./validator-1-custom-contracts.md) — Validator-1 với custom contracts (GTBS)
- [dpos.md](./dpos.md) — Kiến trúc tổng quan
