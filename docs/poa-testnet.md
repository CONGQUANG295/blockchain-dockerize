# Chain POA Docker Testnet Integration

## Go to Project Directory
```
cd docker-compose/chain-poa
```

## For the First time
### 0. Config environment for Testnet
- Copy Environment File (if it doesn't already exist)
  ```
  cp envs/poa.env.example envs/poa.env
  ```
- Open file copied in a text editor
- Add a new line (if it doesn't already exist) that reads:

  `NETWORK_TYPE=testnet`

###  1. Generator validators
- Follow [Generator validators](./poa-mainnet.md#1-generator-validators)

### 2. Create Genesis Block

### 3. Init & Start bootnode
- Follow [Init & Start bootnode](./poa-mainnet.md#3-init--start-bootnode), but using this script `./scripts/get_enode_testnet.sh` to getting bootnode address

### 4. Init & Start validator 1
- Follow [Init & Start validator 1](./poa-mainnet.md#4-init--start-validator-1)

### 5. Init & Start Validator 2
- Follow [Init & Start validator 2](./poa-mainnet.md#4-init--start-validator-2)

### 6. Init & Start RPC
- Follow [Init & Start RPC](./poa-mainnet.md#6-init--start-rpc)

## For the Next time
### 1. Start Bootnode + Validator 1 + Netstats API
```
docker compose -f compose-validator-1.yml up -d
```

### 2. Start Validator 2 + Netstats API
```
docker compose -f compose-validator-2.yml up -d
```

### 3. Start Dapps / RPC
- Using Compose `Blockscout V4`
  ```
  docker compose -f compose-dapps-v4.yml up -d geth
  ```
- Or Using Compose `Blockscout V5`
  ```
  docker compose -f compose-dapps-v4.yml up -d geth
  ```
