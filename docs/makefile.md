# Makefile — blockchain-dockerize

Lớp Makefile mỏng bọc các script bash hiện có. Script vẫn là **source of truth**; `make` chỉ giúp khám phá và gọi lệnh nhất quán.

## Yêu cầu

- GNU Make 4+
- Docker 20.10+, Docker Compose v2
- `jq`, Node.js 18+ (cho genesis / render env DPoS)

## Vị trí làm việc

**Khuyến nghị:** từ root repo `blockchain-dockerize/`:

```bash
make help
make dpos help
make poa help
```

Hoặc trực tiếp trong stack:

```bash
cd docker-compose/chain-dpos
make help
```

> Workspace `blockchain-dock/` (clone cả `blockchain-docker-base` + `blockchain-dockerize` cạnh nhau) có thể dùng Makefile tương tự ở thư mục cha.

## Biến Make phổ biến (DPoS)

| Biến | Mặc định | Ý nghĩa |
|------|----------|---------|
| `WITH_TRAEFIK=1` | `0` | Render domain Traefik / bật stack SSL |
| `CHAIN_ONLY=1` | `0` | Chỉ bootstrap chain, không DApps |
| `DAPPS_ONLY=1` | `0` | Chỉ DApps (chain đã chạy) |
| `SKIP_HEALTH=1` | `0` | Bỏ qua health-check sau deploy |
| `SKIP_GENESIS=1` | `0` | Bootstrap bỏ qua prepare-genesis |
| `SERVER` | _(trống)_ | Override SSH target trên CLI (ưu tiên hơn mọi cờ) |
| `EXPLORER=1` | `0` | Lệnh đa-server → `EXPLORER_SERVER` trong `deploy.env` |
| `SEED=1` | `0` | Lệnh đa-server → `SEED_SERVER` trong `deploy.env` |
| `DAPPS=1` | `0` | Lệnh đa-server → `DAPPS_SERVER` trong `deploy.env` |
| `REMOTE_DIR` | từ `REMOTE_DEPLOY_DIR` trong `deploy.env`, else `/opt/blockchain-dock` | Thư mục deploy trên server |
| `DOCKERHUB_NAMESPACE` | _(trống)_ | Docker Hub user/org khi `make build push` |

### SSH targets trong `envs/deploy.env`

Cấu hình host SSH **theo vai trò** trong `envs/deploy.env` (không cần `export` shell):

| Biến | Ví dụ | Vai trò |
|------|--------|---------|
| `REMOTE_DEPLOY_DIR` | `/opt/blockchain-gtbs` | Path deploy trên mọi server → Make `REMOTE_DIR` |
| `SEED_SERVER` | `root@91.229.245.75` | Validator seed (server 1) |
| `EXPLORER_SERVER` | `root@45.88.188.159` | Explorer + RPC archive (server 3) |
| `DAPPS_SERVER` | `root@203.0.113.70` | Netstats, docs, faucet |

### Cờ chọn server (`EXPLORER=1` | `SEED=1` | `DAPPS=1`)

Lệnh **đa server** (`sync`, `provision-remote`, `setup-ssh`, `sync-peer-bundle`, …) **không** tự chọn host — phải chỉ rõ:

| Cách | Ví dụ |
|------|--------|
| Cờ explorer | `make sync EXPLORER=1` → `EXPLORER_SERVER` |
| Cờ seed | `make sync SEED=1` → `SEED_SERVER` |
| Cờ dapps | `make sync DAPPS=1` → `DAPPS_SERVER` |
| Host tùy ý | `make sync SERVER=root@host` (ưu tiên cao nhất) |

Lệnh **theo vai trò** (tên target đã rõ) — dùng `*_SERVER` trong `deploy.env`, không cần cờ:

| Lệnh | Host mặc định |
|------|----------------|
| `make pull-peer-config` | `SEED_SERVER` |
| `make ssh-deploy-validator` | `SEED_SERVER` |
| `make ssh-deploy-explorer` | `EXPLORER_SERVER` |
| `make ssh-deploy-dapps` | `DAPPS_SERVER` |

Ví dụ `envs/deploy.env`:

```env
REMOTE_DEPLOY_DIR=/opt/blockchain-gtbs
SEED_SERVER=root@91.229.245.75
EXPLORER_SERVER=root@45.88.188.159
DAPPS_SERVER=root@203.0.113.70
```

Luồng explorer (server 3):

```bash
make setup-ssh EXPLORER=1
make provision-remote EXPLORER=1
make sync EXPLORER=1
make sync-peer-bundle EXPLORER=1
make ssh-open-p2p-port EXPLORER=1
make ssh-deploy-explorer          # target explorer — không cần cờ
```

Luồng seed (server 1):

```bash
make sync SEED=1
make ssh-deploy-validator         # target seed — không cần cờ
```

Ví dụ khác:

```bash
make dpos deploy WITH_TRAEFIK=1
make dpos prepare-remote WITH_TRAEFIK=1
make dpos sync                    # EXPLORER_SERVER từ deploy.env
make dpos ssh-deploy-validator    # SEED_SERVER từ deploy.env
make build push DOCKERHUB_NAMESPACE=youruser
```

## Local deploy DPoS

```bash
make dpos init
# chỉnh docker-compose/chain-dpos/envs/deploy.env
make dpos deploy WITH_TRAEFIK=1
```

## Remote deploy

Xem [remote-deploy.md](./remote-deploy.md).

```bash
# Cấu hình SEED_SERVER / EXPLORER_SERVER / DAPPS_SERVER trong envs/deploy.env trước
make dpos prepare-remote WITH_TRAEFIK=1
make dpos sync SEED=1
make dpos ssh-deploy-validator WITH_TRAEFIK=1
```

## Build images

Cần sibling repo `blockchain-docker-base/`:

```bash
make build build-chain
make build push DOCKERHUB_NAMESPACE=youruser
```

## POA

```bash
make poa help
make poa validator-1-up
make poa dapps-v4-up
```

Chi tiết: [poa.md](./poa.md).

## Bảng map Script → Make

| Script | Make target |
|--------|-------------|
| `./scripts/deploy-all.sh --with-traefik` | `make dpos deploy WITH_TRAEFIK=1` |
| `./scripts/local/prepare-deploy.sh` | `make dpos prepare-remote` |
| `./scripts/local/sync-to-server.sh user@host` | `make dpos sync` (hoặc `SERVER=user@host`) |
| `./scripts/remote/deploy-validator.sh` | `make dpos deploy-remote-validator` |
| `./scripts/prepare-envs-validator-1.sh` | `make poa prepare-v1` |
| `./scripts/build-and-push.sh --chain` | `make build build-chain` |

## Liên quan

- [dpos-testnet.md](./dpos-testnet.md)
- [remote-deploy.md](./remote-deploy.md)
