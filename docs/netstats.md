# Netstats Docker Mainnet Integration

## Go to Project Directory
- Using `Chain POA`
  ```
  cd docker-compose/chain-poa
  ```
- Or Using `Chain DPOS`
  ```
  cd docker-compose/chain-dpos
  ```

## For the First time
### 1. Prepare Environments
- Follow [Prepare Environments Dapps](./poa.md#prepare-environments-dapps)

### 2. Config environment
- Copy Environment File (if it doesn't already exist)
  ```
  cp envs/netstats-dashboard.env.example envs/netstats-dashboard.env
  ```
- Open file copied in a text editor
- Add a new line (if it doesn't already exist) that reads:

  `WS_SECRET=<Your_Netstats_Secret_Key>` (required)

  `PORT=<Your_Netstats_Port>` (if need change, default `PORT=3006`)

###  3. Start Netstats Dashboard
```
docker compose -f compose-dapps-v4.yml up -d netstats-dashboard
```

###  4. Config Proxy Netstats Dashboard
- Copy Template File (if it doesn't already exist)
  ```
  cp proxy/status.conf.template.example proxy/status.conf.template
  ```
- Setting environment proxy RPC
  * Copy Environment File (if it doesn't already exist)
    ```
    cp envs/nginx.env.example envs/nginx.env
    ```
  * Open file copied in a text editor
  * Add a new lines (if it doesn't already exist) that reads:<br>
    `STATUS_SERVER_NAME=<Your_Status_Server_Name>`

    `STATUS_PROXY_PASS=<Your_Status_Proxy_Pass>`
- Follow [Generate nginx configuration from template file](./proxy.md#generate-nginx-configuration-from-template-file-and-environment)
- [Start nginx](./proxy.md#start-nginx) or [Reload nginx](./proxy.md#reload-nginx)
- If you want to active SSL for RPC, please follow [Active SSL of Server Name](./proxy.md#active-ssl-of-server-name)

### 5. Start Netstats API (For each Validator)
- Follow [Config Environment Netstast Dashboard](#1-config-environment)
- Setting Environment File
  * Copy Environment File (if it doesn't already exist)
    ```
    cp envs/netstats-api.env.example envs/netstats-api.env
    ```
  * Open fike copied in a text editor
  * Add a new lines (if it doesn't already exist) that reads:
  
    `RPC_HOST=<Your_RPC_Host>` (if need change, default: `RPC_HOST=rpc.host`)

    `WS_SECRET=$WS_SECRET` (if need change, default: using `WS_SECRET` from `envs/netstats-dashboard.env`)

    `WS_SERVER=ws://$WS_HOST:$PORT` (if need change)
  * Start Netstasts API
    - Using `Validator 1`
    ```
    docker compose -f compose-validator-1.yml up -d netstats-api
    ```
    - Or Using `Validator 2`
    ```
    docker compose -f compose-validator-2.yml up -d netstats-api
    ```