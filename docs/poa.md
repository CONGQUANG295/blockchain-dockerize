# Chain POA Docker Integration

## Docs
- For [Mainnet](./poa-mainnet.md)
- For [Testnet](./poa-testnet.md)
- For [Blockscout v4](./explorer-v4.1.8.md)
- For [Blockscout v5](./explorer-v5.2.2.md)
- For [Netstats](./netstats.md)
- For [Docs](./docs.md)
- For [Traefik proxy](./traefik.md)

## Flows
- Setup Validator 1, 2, RPC
- Setup Explorer Blockscout (v4 or v5)
- Setup Netstats Dashboard, Netstats API (for each Validator)
- Setup Socs
- ...

## Prepare Environments
### 1. Go to Project Directory
```
cd docker-compose/chain-poa
```

### 2 Prepare environments
#### Prepare Environments Validator 1
  ```
  ./scripts/prepare-envs-validator-1.sh
  ```
#### Prepare Environments Validator 2
  ```
  ./scripts/prepare-envs-validator-2.sh
  ```
#### Prepare Environments Dapps
- Using `Dapps v4`
  ```
  ./scripts/v4/prepare-envs-dapps.sh
  ```
- Or Using `Dapps v5`
  ```
  ./scripts/v5/prepare-envs-dapps.sh
  ```