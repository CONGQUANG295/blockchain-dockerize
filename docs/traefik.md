# Traefik Proxy Integration

Thay thế **nginx + certbot + envsubst template** bằng **Traefik** với routing qua Docker labels và Let's Encrypt tự động.

## Yêu cầu

- Docker Compose 2.20.3+
- Bash
- DNS trỏ đúng về server trước khi bật ACME
- Image đã build từ [blockchain-docker-base](../blockchain-docker-base) (geth, blockscout, ...)

## So sánh với Nginx

| | Nginx (cũ) | Traefik (mới) |
|--|-----------|---------------|
| SSL | certbot webroot + đổi template | ACME tự động |
| Routing | copy `*.template` → envsubst → reload | Docker labels / file dynamic |
| Thêm domain | sửa template + regenerate | sửa `traefik.env` + `up -d` |
| Compose | `compose-dapps-v4.yml` | `compose-dapps-traefik-v4.yml` |

## Cấu trúc file tham khảo

```
docker-compose/
├── services/
│   ├── compose-traefik.yml              # Traefik base
│   ├── compose-docs-static.yml          # Static docs + error pages
│   └── v5/
│       ├── compose-blockscout-frontend.yml
│       └── compose-blockscout-extras.yml  # stats, visualizer (v5)
├── chain-poa/
│   ├── compose-dapps-traefik-v4.yml     # Stack POA + Traefik + Blockscout v4
│   ├── compose-dapps-traefik-v5.yml     # Stack POA + Traefik + Blockscout v5
│   ├── traefik/
│   │   ├── traefik.yml                  # Static config
│   │   └── dynamic/
│   │       ├── middlewares.yml          # Rate limit, CORS, dashboard auth
│   │       ├── blockscout-v5.yml.template
│   │       └── blockscout-v5.yml        # Generated (gitignored)
│   ├── envs/
│   │   └── traefik.env.example          # Domains + ACME
│   ├── overrides/
│   │   ├── traefik.override.yml
│   │   ├── traefik-rpc.override.yml
│   │   ├── traefik-faucet.override.yml
│   │   ├── traefik-netstats.override.yml
│   │   ├── traefik-blockscout-v4.override.yml
│   │   ├── traefik-blockscout-v5.override.yml
│   │   ├── traefik-docs.override.yml
│   │   ├── traefik-stats.override.yml
│   │   └── traefik-visualize.override.yml
│   └── scripts/traefik/
│       ├── prepare-envs-traefik.sh
│       └── generate-dynamic-config.sh
├── chain-dpos/
│   ├── compose-dapps-traefik-v4.yml     # Stack DPoS + Traefik + Blockscout v4
│   ├── traefik/
│   │   ├── traefik.yml                  # Static config (network: dpos-proxy)
│   │   └── dynamic/middlewares.yml
│   ├── envs/traefik.env.example
│   ├── overrides/traefik-*.override.yml # Labels cho openethereum RPC
│   └── scripts/traefik/prepare-envs-traefik.sh
```

## Quick start (Blockscout v4)

```bash
cd docker-compose/chain-poa

# 1. Chuẩn bị env
./scripts/traefik/prepare-envs-traefik.sh

# 2. Sửa domain + email
vim envs/traefik.env

# 3. Validate compose
docker compose -f compose-dapps-traefik-v4.yml config

# 4. Khởi động
docker compose -f compose-dapps-traefik-v4.yml up -d traefik
docker compose -f compose-dapps-traefik-v4.yml up -d
```

## Quick start (DPoS + Blockscout v4)

```bash
cd docker-compose/chain-dpos

# Sau khi bootstrap chain (Phase A–F)
./scripts/prepare-envs-dapps.sh
vim envs/traefik.env

docker compose -f compose-dapps-traefik-v4.yml config
docker compose -f compose-dapps-traefik-v4.yml up -d traefik
docker compose -f compose-dapps-traefik-v4.yml up -d
```

RPC backend là **OpenEthereum** (`openethereum` service), network Docker `dpos-proxy`. Xem [dpos-testnet.md](./dpos-testnet.md).

## Quick start (Blockscout v5)

```bash
cd docker-compose/chain-poa
./scripts/traefik/prepare-envs-traefik.sh
vim envs/traefik.env

# Bắt buộc: generate routing phức tạp frontend/backend
./scripts/traefik/generate-dynamic-config.sh

docker compose -f compose-dapps-traefik-v5.yml up -d
```

## Cấu hình môi trường (`envs/traefik.env.example`)

```env
ACME_EMAIL=admin@example.com
NETWORK_TYPE=mainnet

RPC_SERVER_NAME=mainnet-rpc.example.com
BLOCKSCOUT_BACK_SERVER_NAME=explorer.example.com   # v4
BLOCKSCOUT_FRONT_SERVER_NAME=explorer.example.com  # v5
STATUS_SERVER_NAME=status.example.com
FAUCET_SERVER_NAME=faucet.example.com
DOCS_SERVER_NAME=docs.example.com
STATS_SERVER_NAME=stats.example.com
VISUALIZE_SERVER_NAME=visualize.example.com

TRAEFIK_DASHBOARD_HOST=traefik.example.com
```

## Mapping service → config

| Service | File override | Port | Host env |
|---------|--------------|------|----------|
| Geth RPC (POA) | `traefik-rpc.override.yml` | 8545 | `RPC_SERVER_NAME` |
| OpenEthereum RPC (DPoS) | `chain-dpos/overrides/traefik-rpc.override.yml` | 8545 | `RPC_SERVER_NAME` |
| Blockscout v4 | `traefik-blockscout-v4.override.yml` | 4000 | `BLOCKSCOUT_BACK_SERVER_NAME` |
| Blockscout v5 | `traefik/dynamic/blockscout-v5.yml` | 4000 + 5004 | `BLOCKSCOUT_FRONT_SERVER_NAME` |
| Faucet | `traefik-faucet.override.yml` | 8080 | `FAUCET_SERVER_NAME` |
| Netstats | `traefik-netstats.override.yml` | 3006 | `STATUS_SERVER_NAME` |
| Docs | `traefik-docs.override.yml` | 80 | `DOCS_SERVER_NAME` |
| Stats (v5) | `traefik-stats.override.yml` | 8050 | `STATS_SERVER_NAME` |
| Visualize (v5) | `traefik-visualize.override.yml` | 9050 | `VISUALIZE_SERVER_NAME` |
| Traefik dashboard | `traefik.override.yml` | — | `TRAEFIK_DASHBOARD_HOST` |

## Middleware dùng chung (`traefik/dynamic/middlewares.yml`)

| Middleware | Mục đích |
|-----------|----------|
| `secure-headers` | `X-Forwarded-Proto: https` |
| `rpc-ratelimit` | Giới hạn 100 req/s cho JSON-RPC |
| `metrics-deny` | Chặn `/metrics` public (403) |
| `dashboard-auth` | Basic auth cho Traefik dashboard |
| `stats-cors` | CORS cho stats service (v5) |
| `visualize-cors` | CORS cho visualizer (v5) |

Đổi password dashboard:

```bash
htpasswd -nb admin yourpassword
# Copy hash vào middlewares.yml → dashboard-auth.users
```

Đổi CORS origin (stats/visualize): sửa `accessControlAllowOriginList` trong `middlewares.yml`.

## SSL / ACME

- HTTP-01 challenge qua entrypoint `web` (:80)
- Cert lưu tại `data/traefik/letsencrypt/acme.json` (chmod 600)
- HTTP tự redirect sang HTTPS (`traefik.yml`)

Test cert (dry-run không có sẵn trong Traefik — dùng staging resolver nếu cần):

```yaml
# Thêm vào traefik.yml để test (không dùng production)
certificatesResolvers:
  letsencrypt-staging:
    acme:
      caServer: https://acme-staging-v02.api.letsencrypt.org/directory
      ...
```

## Blockscout v5 — path routing

File `blockscout-v5.yml.template` mirror logic nginx v5:

- `/` exact → backend (:4000)
- `/_next`, `/tx`, `/blocks`, ... → backend
- `/css`, `/js` → frontend (:5004)
- catch-all → frontend
- `/metrics` → deny (403)

Regenerate sau khi đổi domain:

```bash
./scripts/traefik/generate-dynamic-config.sh
```

## RPC — bảo mật bổ sung

Mặc định có `rpc-ratelimit`. Để whitelist IP, bỏ comment trong `middlewares.yml`:

```yaml
rpc-ipwhitelist:
  ipAllowList:
    sourceRange:
      - "10.0.0.0/8"
```

Gắn vào router trong `traefik-rpc.override.yml`:

```yaml
- traefik.http.routers.${NETWORK_TYPE:-mainnet}-rpc.middlewares=secure-headers@file,rpc-ratelimit@file,rpc-ipwhitelist@file
```

## Chỉ bật một số service

Traefik chỉ route service có `traefik.enable=true`. Các service không có label sẽ không public.

Ví dụ testnet không cần faucet: không include `traefik-faucet.override.yml` trong compose, hoặc xóa block eth-faucet.

## Migrate từ Nginx

1. Dừng nginx (giải phóng :80/:443):
   ```bash
   docker compose -f compose-dapps-v4.yml stop nginx certbot
   ```
2. Copy domain từ `envs/nginx.env` sang `envs/traefik.env`
3. Chạy `prepare-envs-traefik.sh`
4. `docker compose -f compose-dapps-traefik-v4.yml up -d traefik`
5. Kiểm tra HTTPS từng domain
6. Cert cũ trong `data/certbot/` không dùng nữa — Traefik cấp cert mới

## Troubleshooting

| Vấn đề | Cách xử lý |
|--------|-----------|
| ACME fail | Kiểm tra DNS, port 80 mở, không có nginx chiếm :80 |
| 404 từ Traefik | `docker logs traefik`, kiểm tra label `traefik.enable=true` |
| WebSocket lỗi | Traefik hỗ trợ sẵn; kiểm tra backend listen đúng port |
| v5 routing sai | Regenerate `blockscout-v5.yml`, so sánh với nginx template cũ |
| Dashboard 401 | Cập nhật `dashboard-auth` trong `middlewares.yml` |

Xem route đang active:

```bash
docker compose -f compose-dapps-traefik-v4.yml logs traefik
# Hoặc truy cập dashboard tại https://$TRAEFIK_DASHBOARD_HOST
```

## Liên quan

- [POA setup](./poa.md)
- [Proxy Nginx (legacy)](./proxy.md)
- [Blockscout v4](./explorer-v4.1.8.md)
- [Netstats](./netstats.md)
