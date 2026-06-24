# GTBS Custom Staking (opt-in profile)

Enable GTBS custom staking contracts when deploying a DPoS chain. Standard chains leave `ENABLE_CUSTOM_STAKING=false` (default).

## Enable

1. In `envs/deploy.env`:
   ```bash
   ENABLE_CUSTOM_STAKING=true
   MAX_STAKE_TOKENS=300000000
   MIN_DELEGATION_TOKENS=10000
   MAX_DELEGATION_PER_WALLET_TOKENS=100000
   NET_APY_PERCENT=4
   ANNUAL_UNLOCK_CAP_TOKENS=500000
   ```

2. Render envs and bootstrap:
   ```bash
   ./scripts/render-envs.sh envs/deploy.env
   ./scripts/bootstrap-chain.sh
   ```

3. Rebuild deployer image if contracts changed:
   ```bash
   docker build -f blockchain-docker-base/docker/Dockerfile.dpos-deployer -t dpos-deployer:0.0.1 blockchain-docker-base
   ```

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
