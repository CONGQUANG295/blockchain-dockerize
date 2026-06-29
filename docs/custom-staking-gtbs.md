# GTBS Custom Staking (opt-in profile)

Enable GTBS custom staking contracts when deploying a DPoS chain. Standard chains leave `ENABLE_CUSTOM_STAKING=false` (default).

> **Runbook deploy validator-1:** [validator-1-custom-contracts.md](./validator-1-custom-contracts.md) — từ build image → sync server → bootstrap + validator-app + netstats-api.

## Enable

1. In `envs/deploy.env`:
   ```bash
   ENABLE_CUSTOM_STAKING=true
   PREMINE_BALANCE_WEI=1500000000000000000000000000   # 1.5B premine
   MAX_SUPPLY_WEI=3000000000000000000000000000          # 3B cap (premine + mining pool)
   BLOCK_TIME_SECONDS=3                               # BLOCKS_PER_YEAR auto-derived (31536000 / block time)
   MAX_STAKE_TOKENS=300000000
   MIN_DELEGATION_TOKENS=10000
   MAX_DELEGATION_PER_WALLET_TOKENS=100000
   NET_APY_PERCENT=4
   ANNUAL_UNLOCK_CAP_TOKENS=500000
   ```
   `INITIAL_SUPPLY_GWEI` and `BLOCKS_PER_YEAR` are **derived** by `render-envs.sh` — do not set them manually.

2. Prepare (patches `.sol`, compile, test, genesis):
   ```bash
   make dpos gtbs-prepare
   make dpos sync SERVER=user@host
   make dpos ssh-deploy-validator SERVER=user@host
   ./scripts/verify-contracts-transition.sh
   ```

3. Rebuild deployer image when contract sources change:
   ```bash
   docker build -f blockchain-docker-base/docker/Dockerfile.dpos-deployer -t dpos-deployer:0.0.1 blockchain-docker-base
   ```
   The deploy container re-patches and recompiles from mounted env before deploy (avoids stale `.example` defaults in the image).

## Tokenomics (new chain)

| Pool | Amount |
|------|--------|
| Genesis premine | `PREMINE_BALANCE_WEI` at `PREMINE_ADDRESS` |
| Mining (block rewards) | `MAX_SUPPLY_WEI - PREMINE_BALANCE_WEI` |
| Max supply | `MAX_SUPPLY_WEI` (enforced on-chain in `BlockReward`) |

Governance can call `setNetApyBps(0)` when supply nears cap. Monitor with `./scripts/check-supply-cap.sh`.

## Enable (manual render)

## Deployed contracts

| Key | Contract |
|-----|----------|
| `consensusProxy` | GTBS `Consensus` (canonical name, custom bytecode) |
| `blockRewardProxy` | GTBS `BlockReward` (4% NET APY) |
| `stakingVault` | `StakingVault` (user entry point) |

`patch-spec-after-deploy.sh` reads `consensusProxy` / `blockRewardProxy` — no script changes required.

## User flows

All stake / delegate / withdraw / unstake go through **StakingVault**. Direct `Consensus.stake()` reverts.

## Owner config (runtime)

### Tier 1 — StakingVault

| Setter | Default source |
|--------|----------------|
| `setDelegatorLockPeriod` | `DELEGATOR_LOCK_DAYS` |
| `setAnnualUnlockPeriod` | `ANNUAL_UNLOCK_PERIOD_DAYS` |
| `setReleaseDelayPeriod` | `RELEASE_DELAY_DAYS` |
| `setAnnualUnlockCap` | `ANNUAL_UNLOCK_CAP_TOKENS` |
| `setUnstakeFeeBps` | `UNSTAKE_FEE_BPS` |

Snapshots at delegate / unstake — owner changes are not retroactive.

### Tier 2 — Consensus + BlockReward

| Setter | Effect |
|--------|--------|
| `setMinDelegation` | new delegations only |
| `setMaxDelegationPerWallet` | new delegations only |
| `setNetApyBps` | effective block N+1 |

### Tier 3 — governance only (defer v1)

`MIN_STAKE`, `MAX_STAKE`, `MAX_VALIDATORS`, 1:1 ratio — require Voting ballot.

## staking-keeper

```bash
# After deploy, set envs/staking-keeper.env from genesis/contract-addresses.json
docker compose -f compose-custom-staking.yml --profile custom-staking up -d staking-keeper
```

Keeper polls `PendingUnstakeInitiated` events and calls `completeUnstake` when `releaseDelayPeriod` elapsed. Reads durations from on-chain views.

## Solidity

Package `custom-staking-contracts` uses **solc 0.4.24** (same as standard `dpos-contracts`). Contract names are canonical: `Consensus`, `BlockReward`, `StakingVault`.

## Tests

```bash
cd blockchain-docker-base/resources/custom-staking-contracts
npm test
```

Optional Blockscout verify: flattened sources are written automatically during deploy:

- **Local prepare** (`make dpos gtbs-prepare`): `genesis/flats/*.sol`, `genesis/gtbs-deploy-config.json`, `genesis/gtbs-deploy-manifest.json`
- **Server deploy** (container `dpos-deployer`): same files under `genesis/` via volume mount

After seed deploy, pull to operator: `make dpos pull-peer-config` (includes `genesis/flats/`).

Flatten reflects env-patched Solidity constants (`MIN_STAKE`, `MAX_SUPPLY`, `BLOCKS_PER_YEAR`, …). Initialize args (`netApyBps`, staking vault timings, premine) are in `gtbs-deploy-manifest.json` → `blockscoutVerify.initializeParams`.
