# Docs Docker Mainnet Integration

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
  cp envs/docs.env.example envs/docs.env
  ```
- Open file copied in a text editor
- Add a new line (if it doesn't already exist) that reads:

  `DOCS_NAME=<Your_Ecosystem_Name>` (Ex: `Miexs`)

  `DOCS_NAMECHAIN=<Your_Name_Chain>` (if need change, default is `$DOCS_NAME Chain`, Ex: `Mixes Chain`)

  `DOCS_NAMECOIN=<Your_Name_Coin>` (if need change, default is `$DOCS_NAME Coin`, Ex: `Miexs Coin`)

  `DOCS_SYMBOL=<Your_Symbol>` (uppercase)

  `DOCS_TOKENSTANDARD=<Your_Token_Standard_Name>` (if need change, default is `$DOCS_SYMBOL`, Ex: `MIX`)

  `DOCS_MAINNETID=<Your_Mainnet_Id>`
  `DOCS_TESTNETID=<Your_Testnet_Id>`

  `DOCS_DOMAINCHAIN=<Your_Domain_Chain>` (Ex: `miexs.com`)

  `DOCS_GITHUBUSERNAME=<Your_Github_User_Or_Organization_Name>`

  `DOCS_GITHUBREPO=<Your_Github_Repo>`

###  3. Prepare Docs from Variables
```
docker compose -f compose-dapps-v4.yml run --rm --entrypoint ./prepare.sh docs
```

###  4. Build Docs
```
docker compose -f compose-dapps-v4.yml run --rm --entrypoint ./build.sh docs
```

###  4. Config Proxy Docs
- Copy Template File (if it doesn't already exist)
  ```
  cp proxy/docs.conf.template.example proxy/docs.conf.template
  ```
- Setting environment proxy Dos
  * Copy Environment File (if it doesn't already exist)
    ```
    cp envs/nginx.env.example envs/nginx.env
    ```
  * Open file copied in a text editor
  * Add a new lines (if it doesn't already exist) that reads:<br>
    `DOCS_SERVER_NAME=<Your_Docs_Server_Name>`

- Follow [Generate nginx configuration from template file](./proxy.md#generate-nginx-configuration-from-template-file-and-environment)
- [Start nginx](./proxy.md#start-nginx) or [Reload nginx](./proxy.md#reload-nginx)
- If you want to active SSL for Docs, please follow [Active SSL of Server Name](./proxy.md#active-ssl-of-server-name)