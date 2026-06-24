# Faucet Docker Mainnet Integration

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
  cp envs/eth-faucet.env.example envs/eth-faucet.env
  ```
- Open file copied in a text editor
- Add a new line (if it doesn't already exist) that reads:

  `WEB3_PROVIDER=<Your_WEB3_Provider>`

  `PRIVATE_KEY=<Your_Private_Key_as_Sender>`

###  3. Start Faucet
```
docker compose -f compose-dapps-v4.yml up -d eth-faucet
```

###  4. Config Proxy Faucet
- Copy Template File (if it doesn't already exist)
  ```
  cp proxy/faucet.conf.template.example proxy/faucet.conf.template
  ```
- Setting environment proxy Faucet
  * Copy Environment File (if it doesn't already exist)
    ```
    cp envs/nginx.env.example envs/nginx.env
    ```
  * Open file copied in a text editor
  * Add a new lines (if it doesn't already exist) that reads:
  
    `FAUCET_SERVER_NAME=<Your_Faucet_Server_Name>`

    `FAUCET_PROXY_PASS=<Your_Faucet_Proxy_Pass>`
- Follow [Generate nginx configuration from template file](./proxy.md#generate-nginx-configuration-from-template-file-and-environment)
- [Start nginx](./proxy.md#start-nginx) or [Reload nginx](./proxy.md#reload-nginx)
- If you want to active SSL for RPC, please follow [Active SSL of Server Name](./proxy.md#active-ssl-of-server-name)