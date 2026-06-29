# Blockscout custom explorer theme (GTBS profile)

Optional branding and DPoS homepage widgets for Blockscout v11 (`2.8.1` / `11.2.1`). When disabled, the explorer matches upstream Blockscout behavior.

## Enable GTBS profile

1. Set in `envs/deploy.env`:

```bash
EXPLORER_CUSTOM_PROFILE=gtbs
EXPLORER_HERO_TITLE="GTBS Blockchain Explorer"   # quote values with spaces
EXPLORER_ASSETS_BASE_URL=https://raw.githubusercontent.com/gtbschain/assets/master/explorer
```

2. Render env (local, before sync):

```bash
make render WITH_TRAEFIK=1
```

Merges `blockscout-frontend.gtbs.env.example` and `blockscout-backend.gtbs.env.example` into `envs/blockscout-frontend.env` / `blockscout-backend.env`.  
`NEXT_PUBLIC_CONSENSUS_ADDRESS` and `NEXT_PUBLIC_STAKING_VAULT_ADDRESS` are injected from `genesis/contract-addresses.json` when present.

3. Deploy explorer — `deploy-explorer.sh` / `make ssh-deploy-explorer` **tự động** thêm `overrides/v11/blockscout-frontend-gtbs.override.yml` khi `EXPLORER_CUSTOM_PROFILE=gtbs`.

### Logo / icon assets (GitHub)

GTBS profile dùng **URL GitHub** (không mount local, không `file://`):

| Biến | Nguồn |
|------|--------|
| `NEXT_PUBLIC_NETWORK_LOGO` | `${EXPLORER_ASSETS_BASE_URL}/network_logo.png` |
| `NEXT_PUBLIC_NETWORK_LOGO_DARK` | `.../network_logo_dark.png` |
| `NEXT_PUBLIC_NETWORK_ICON` | `.../network_icon.svg` |
| `NEXT_PUBLIC_NETWORK_ICON_DARK` | `.../network_icon_dark.svg` |
| `NEXT_PUBLIC_FEATURED_NETWORKS` | `.../featured_networks.json` |

Blockscout frontend **tải các file này lúc khởi động** (`download_assets.sh`). Server explorer cần outbound HTTPS tới `raw.githubusercontent.com`.

`SKIP_ENVS_VALIDATION=true` được set qua GTBS override vì image chưa embed placeholder `NEXT_PUBLIC_STAKING_VAULT_ADDRESS` lúc build.

## DPoS widgets (no profile required)

| Variable | Purpose |
|----------|---------|
| `NEXT_PUBLIC_CONSENSUS_ADDRESS` | Consensus contract (required) |
| `NEXT_PUBLIC_NETWORK_RPC_URL` | Public RPC (required) |
| `NEXT_PUBLIC_BLOCK_TIME_SECONDS` | Block time for cycle math |
| `NEXT_PUBLIC_VALIDATORS_STATUS_URL` | Optional link on Active Validators widget |
| `NEXT_PUBLIC_DPOS_GAUGE_COLOR` | Cycle gauge color (default `#FFC107`) |

## Branding env vars (GTBS profile)

| Variable | Purpose |
|----------|---------|
| `NEXT_PUBLIC_HOMEPAGE_HERO_TITLE` | Hero H1 |
| `NEXT_PUBLIC_HOMEPAGE_HERO_BANNER_CONFIG` | Hero gradient / button colors |
| `NEXT_PUBLIC_COLOR_THEME_OVERRIDES` | Yellow accent theme |
| `NEXT_PUBLIC_FOOTER_PROJECT_CONFIG` | Left footer column JSON |

## Backend token icons

| Variable | Purpose |
|----------|---------|
| `TOKEN_ICON_CHAIN_SLUG` | Chain slug in assets repo (e.g. `gtbs`) |
| `TOKEN_ICON_ASSETS_BASE_URL` | Base URL for token logo paths |

## Regression check

Deploy **without** `EXPLORER_CUSTOM_PROFILE`:

- No DPoS widgets on homepage
- Default Blockscout footer
- Default hero title and theme
