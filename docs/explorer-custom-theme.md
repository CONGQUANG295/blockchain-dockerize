# Blockscout custom explorer theme (GTBS profile)

Optional branding and DPoS homepage widgets for Blockscout v11 (`2.8.1` / `11.2.1`). When disabled, the explorer matches upstream Blockscout behavior.

## Enable GTBS profile

1. Set in `envs/deploy.env`:

```bash
EXPLORER_CUSTOM_PROFILE=gtbs
EXPLORER_HERO_TITLE=GTBS Blockchain Explorer   # optional override
```

2. Run `./scripts/render-envs.sh envs/deploy.env --with-traefik` — merges `blockscout-frontend.gtbs.env.example` and `blockscout-backend.gtbs.env.example` into rendered env files.

3. Mount GTBS assets when starting compose:

```bash
docker compose -f compose-dapps-traefik-v11.yml \
  -f overrides/v11/blockscout-frontend-gtbs.override.yml up -d
```

4. Set `NEXT_PUBLIC_CONSENSUS_ADDRESS` in `envs/blockscout-frontend.env` (or gtbs example) to the deployed consensus contract from `contract-addresses.json`.

## DPoS widgets (no profile required)

Set these env vars on the frontend to enable on-chain stats without full GTBS branding:

| Variable | Purpose |
|----------|---------|
| `NEXT_PUBLIC_CONSENSUS_ADDRESS` | Consensus contract (required) |
| `NEXT_PUBLIC_NETWORK_RPC_URL` | Public RPC (required) |
| `NEXT_PUBLIC_BLOCK_TIME_SECONDS` | Block time for cycle math (default `5`) |
| `NEXT_PUBLIC_VALIDATORS_STATUS_URL` | Optional link on Active Validators widget |
| `NEXT_PUBLIC_DPOS_GAUGE_COLOR` | Cycle gauge color (default `#FFC107`) |

## Branding env vars (GTBS profile)

| Variable | Purpose |
|----------|---------|
| `NEXT_PUBLIC_HOMEPAGE_HERO_TITLE` | Hero H1 (precedence over banner config text) |
| `NEXT_PUBLIC_HOMEPAGE_HERO_BANNER_CONFIG` | Hero gradient / button colors |
| `NEXT_PUBLIC_COLOR_THEME_OVERRIDES` | Yellow accent theme |
| `NEXT_PUBLIC_FOOTER_PROJECT_CONFIG` | Left footer column JSON |
| `NEXT_PUBLIC_FOOTER_LINKS` | Right footer link groups |
| `NEXT_PUBLIC_NETWORK_LOGO` / `ICON` | Mounted from `assets/explorer/gtbs/` |

## Backend token icons

| Variable | Purpose |
|----------|---------|
| `TOKEN_ICON_CHAIN_SLUG` | Chain slug in assets repo (e.g. `gtbs`) |
| `TOKEN_ICON_ASSETS_BASE_URL` | Base URL for token logo paths |

## Migration from `env_blockschain.txt`

| Legacy | v11 replacement |
|--------|-----------------|
| `CONSENSUS_ADDRESS` | `NEXT_PUBLIC_CONSENSUS_ADDRESS` |
| `BLOCK_TIME_SECONDS` / cycle timing | `NEXT_PUBLIC_BLOCK_TIME_SECONDS` (single source) |
| Hardcoded ZiCoin strings | `NEXT_PUBLIC_HOMEPAGE_HERO_TITLE` + `FOOTER_PROJECT_CONFIG` |
| `FOOTER_LINKS` URL | `NEXT_PUBLIC_FOOTER_LINKS` + mounted `footer-links.json` |
| Token icon chain `zi` | `TOKEN_ICON_CHAIN_SLUG` on backend |

## Limitations

- `FooterInfoModal` from explorer_v2 is not ported (P2).
- DPoS widgets require live RPC + deployed consensus contract.
- GTBS assets volume mount is required for `file:///assets/configs/*` paths.

## Regression check

Deploy **without** `NEXT_PUBLIC_CONSENSUS_ADDRESS` and **without** `EXPLORER_CUSTOM_PROFILE`:

- No DPoS widgets on homepage
- Default Blockscout footer ("Made with Blockscout")
- Default hero title and theme
