# Proxy Nginx Docker Integration

## Go to Project Directory
- Using `Chain POA`
  ```
  cd docker-compose/chain-poa
  ```
- Or Using `Chain DPOS`
  ```
  cd docker-compose/chain-dpos
  ```

## For The First Time
### Prepare Environments
- Follow [Prepare Environments Dapps](./poa.md#prepare-environments-dapps)

### Generate Nginx Configuration from Template File and Environment
- Using Compose `Blockscout V4`
  ```
  docker compose -f compose-dapps-v4.yml run --rm --entrypoint ./docker-entrypoint.d/20-envsubst-on-templates.sh nginx
  ```
- Or Using Compose `Blockscout V5`
  ```
  docker compose -f compose-dapps-v5.yml run --rm --entrypoint ./docker-entrypoint.d/20-envsubst-on-templates.sh nginx
  ```

### Start nginx
- Using Compose `Blockscout V4`
  ```
  docker compose -f compose-dapps-v4.yml up -d nginx
  ```
- Or Using Compose `Blockscout V5`
  ```
  docker compose -f compose-dapps-v5.yml up -d nginx
  ```

### Reload Nginx
- Using Compose `Blockscout V4`
  ```
  docker compose -f compose-dapps-v4.yml exec nginx service nginx reload
  ```
- Or Using Compose `Blockscout V5`
  ```
  docker compose -f compose-dapps-v5.yml exec nginx service nginx reload
  ```

### Active SSL of Server Name
- Generate Certificates With Letsencrypt
  * Using Compose `Blockscout V4`
    ```
    docker compose -f compose-dapps-v4.yml run --rm certbot certonly --webroot --webroot-path /var/www/certbot/ --dry-run -d <Your_Server_Name>
    ```
  * Or Using Compose `Blockscout V5`
    ```
    docker compose -f compose-dapps-v5.yml run --rm certbot certonly --webroot --webroot-path /var/www/certbot/ --dry-run -d <Your_Server_Name>
    ```

- Remove old config `non-ssl` file of `Server Name` (from your volume proxy conf.d)
- Copy template config `ssl` file of `Server Name` (commonly name `*.ssl-template`) from example file (commonly name `*.ssl-template.example`)
  ```
  cp proxy/<file>.ssl-template.example proxy/<file>.ssl-template
  ```
- Generate Nginx Configuration from Template File and Environment
  * Using Compose `Blockscout V4`
    ```
    docker compose -f compose-dapps-v4.yml run --rm --entrypoint ./docker-entrypoint.d/20-envsubst-on-templates.sh -e NGINX_ENVSUBST_TEMPLATE_SUFFIX=.ssl-template nginx
    ```
  * Or Using Compose `Blockscout V5`
    ```
    docker compose -f compose-dapps-v5.yml run --rm --entrypoint ./docker-entrypoint.d/20-envsubst-on-templates.sh -e NGINX_ENVSUBST_TEMPLATE_SUFFIX=.ssl-template nginx
    ```
- Remove old template config `non-ssl` file of `Server Name` (inside proxy folder)
- [Reload nginx](#reload-nginx)