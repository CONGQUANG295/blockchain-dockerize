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
| `SERVER` | _(trống)_ | SSH target cho sync / provision |
| `REMOTE_DIR` | `/opt/blockchain-dock` | Thư mục deploy trên server |
| `DOCKERHUB_NAMESPACE` | _(trống)_ | Docker Hub user/org khi `make build push` |

Ví dụ:

```bash
make dpos deploy WITH_TRAEFIK=1
make dpos sync SERVER=ubuntu@your-server
make build build-chain
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
make dpos prepare-remote WITH_TRAEFIK=1
make dpos sync SERVER=ubuntu@your-server
make dpos ssh-deploy-validator SERVER=ubuntu@your-server WITH_TRAEFIK=1
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
| `./scripts/local/sync-to-server.sh user@host` | `make dpos sync SERVER=user@host` |
| `./scripts/remote/deploy-validator.sh` | `make dpos deploy-remote-validator` |
| `./scripts/prepare-envs-validator-1.sh` | `make poa prepare-v1` |
| `./scripts/build-and-push.sh --chain` | `make build build-chain` |

## Liên quan

- [dpos-testnet.md](./dpos-testnet.md)
- [remote-deploy.md](./remote-deploy.md)
