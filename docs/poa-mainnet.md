# Chain POA Docker Mainnet Integration

## Go to Project Directory
```
cd docker-compose/chain-poa
```

## For the First time
###  1. Generator validators

#### 1.1 Prepare environments
- Follow [Prepare Environment Validator 1](./poa.md#prepare-environments-validator-1)
- Follow [Prepare Environment Validator 1](./poa.md#prepare-environments-validator-2)
- Follow [Prepare Environment Dapps](./poa.md#prepare-environments-dapps)

#### 1.2 Generate account validator 1
```
docker compose -f compose-validator-1.yml run --rm --entrypoint entrypoints/create-account.sh geth
```

#### Setting validator address
- Once you have the result, locate the public address within the output.
- Copy this address to your clipboard or note it down.
- Setting VALIDATOR_ADDRESS
  + Copy Environment File (if it doesn't already exist)
    ```
      cp envs/validator-1.env.example envs/validator-1.env
    ```
  + Open file copied in a text editor
  + Add a new line (if it doesn't already exist) that reads:
  `VALIDATOR_ADDRESS=<Your_Copied_Public_Address>`

#### 1.3 Generate account validator 2
```
docker compose -f compose-validator-2.yml run --rm --entrypoint entrypoints/create-account.sh geth
```
- Follow [Setting validator address](#setting-validator-address), but using command below to copy Envronment File
  ```
  cp envs/validator-2.env.example envs/validator-2.env
  ```

### 2. Create Genesis Block

### 3. Init & Start bootnode

#### 3.1 Generate key bootnode
```
docker compose -f compose-validator-1.yml run --rm --entrypoint entrypoints/gen-key.sh bootnode
```

#### 3.2 Start bootnode
```
docker compose -f compose-validator-1.yml up -d bootnode
```

#### Getting bootnode address
* Execute `./scripts/get_enode_mainnet.sh` and in result string replace `[::]` with server's public ip address. You will get something similar to `enode://b4237b154a99cc729f4731348de518410c83d0b798fa153308140e4b9a5098a5a9f116115d3fd8245038bab9f08dfd804f60724ad39af080eda9a2d4674dce6d@172.17.0.2:30303`
* Open validator's config file (.toml), replace `BootstrapNodes` with enode and server's public ip address

### 4. Init & Start validator 1
#### 4.1 Init validator 1
```
docker compose -f compose-validator-1.yml run --rm --entrypoint entrypoints/init-node.sh geth
```

#### 4.2 Start validator 1
```
docker compose -f compose-validator-1.yml up -d geth
```

#### Getting enode's validator
- Exec sh to validator container
  ```
  docker compose -f compose-validator-1.yml exec -it geth /bin/sh
  ```
- Attack validator with http://<node_http_host>:<node_http_port>
  ```
  ./geth attach http://localhost:3545
  admin.nodeInfo
  ```
You will get enode and enr address

### 5. Init & Start Validator 2
#### 5.1 Init validator 2
```
docker compose -f compose-validator-2.yml run --rm --entrypoint entrypoints/init-node.sh geth
```

#### Start validator 2
* Open config file of chain, update `StaticNodes` with `validator-1 enode/enr`
* Start node
  ```
  docker compose -f compose-validator-2.yml up -d geth
  ```

* Follow [Getting enode's validator](#getting-enodes-validator), replace `compose-validator-1.yml` with your validator docker compose file

### 6. Init & Start RPC
#### 6.1 Init RPC
- Using Compose `Blockscout V4`
  ```
  docker compose -f compose-dapps-v4.yml run --rm --entrypoint entrypoints/init-node.sh geth
  ```
- Or Using Compose `Blockscout V5`
  ```
  docker compose -f compose-dapps-v5.yml run --rm --entrypoint entrypoints/init-node.sh geth
  ```
#### 6.2 Start RPC
- Open config file of chain, update `StaticNodes` with `validator-1 enode/enr`, `validator-2 enode/enr`
- Using Compose `Blockscout V4`
  ```
  docker compose -f compose-dapps-v4.yml up -d geth
  ```
- Or Using Compose `Blockscout V5`
  ```
  docker compose -f compose-dapps-v5.yml up -d geth
  ```
#### 6.3 Config proxy RPC

- Copy Template File (if it doesn't already exist)
  ```
  cp proxy/rpc.conf.template.example proxy/rpc.conf.template
  ```
- Setting environment proxy RPC
  * Copy Environment File (if it doesn't already exist)
    ```
    cp envs/nginx.env.example envs/nginx.env
    ```
  - Open file copied in a text editor
  - Add a new lines (if it doesn't already exist) that reads:
  
  `RPC_SERVER_NAME=<Your_RPC_Server_Name>`

  `RPC_PROXY_PASS=<Your_RPC_Proxy_Pass>`
- Follow [Generate nginx configuration from template file](./proxy.md#generate-nginx-configuration-from-template-file-and-environment)
- [Start nginx](./proxy.md#start-nginx) or [Reload nginx](./proxy.md#reload-nginx)
- If you want to active SSL for RPC, please follow [Active SSL of Server Name](./proxy.md#active-ssl-of-server-name)

## For the Next time
### 1. Start Bootnode & Validator 1
```
docker compose -f compose-validator-1.yml up -d
```

### 2. Start Validator 2
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
