# BlockScout Docker Integration v4.1.8

> **DPoS:** New DPoS deployments use **Blockscout v11** (`compose-dapps-traefik-v11.yml`). See [explorer-v11.md](./explorer-v11.md). This document is retained for **POA** and legacy v4 reference.

## Go to Project Directory
- For POA
  ```
  cd docker-compose/chain-poa
  ```

- For DPOS
  ```
  cd docker-compose/chain-dpos
  ```

## For the First time
### 1. Prepare Environments
- Follow [Prepare Environments Dapps](./poa.md#prepare-environments-dapps)

### 2. Start Postgres
```
docker compose -f compose-dapps-v4.yml up -d db
```

### 3. Generate secret
```
docker compose -f compose-dapps-v4.yml run --rm --entrypoint entrypoints/gen-secret.sh blockscout
```
- Copy Environment File (if it doesn't already exist)
  ```
  cp envs/blockscout.env.example envs/blockscout.env
  ```
- Open file copied in a text editor
- Add a new line (if it doesn't already exist) that reads:

  `SECRET_KEY_BASE=<Your_Copied_Secret_Key>`

### 4. Create database
```
docker compose -f compose-dapps-v4.yml run --rm --entrypoint entrypoints/create.sh blockscout

```
### 5. Start Blockscout
```
docker compose -f compose-dapps-v4.yml up -d blockscout
```

### 6. Config proxy Blockscout

- Copy Template File (if it doesn't already exist)
  ```
  cp proxy/v4/blockscout.conf.template.example proxy/blockscout.conf.template
  ```
- Setting environment proxy Blockscout
  * Copy Environment File (if it doesn't already exist)
    ```
    cp envs/nginx.env.example envs/nginx.env
    ```
  - Open file copied in a text editor
  - Add a new lines (if it doesn't already exist) that reads:

  `BLOCKSCOUT_BACK_SERVER_NAME=<Your_Blockscout_Server_Name>`

  `BLOCKSCOUT_BACK_PROXY_PASS=<Your_Blockscout_Proxy_Pass>`
- Follow [Generate nginx configuration from template file](./proxy.md#generate-nginx-configuration-from-template-file-and-environment)
- [Start nginx](./proxy.md#start-nginx) or [Reload nginx](./proxy.md#reload-nginx)
- If you want to active SSL for RPC, please follow [Active SSL of Server Name](./proxy.md#active-ssl-of-server-name)