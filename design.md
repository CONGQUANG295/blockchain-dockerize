## Docker Structure

### POA

#### mainnet dapps + rpc
- blockscout
- rpc
- status
- verify-contract (v5)
- visualizer (v5)

#### mainnet validator 1
- bootnode
- geth

#### mainnet validator 2
- geth

#### testnet validator 1
- bootnode
- geth (rpc)
- blockscout
- faucet
- status
- verify-contract (v5)
- visualizer (v5)

#### testnet validator 2
- geth

### DPOS

#### mainnet dapps + rpc
- blockscout
- rpc
- status
- visualizer (v5)

#### mainnet bootnodes
- bot staking
- graphnode
- ipfs
- moc
- status

#### mainnet validator 1
- openethereum
- app interact consensus
- intelligence-api

#### mainnet validator 2
- openethereum
- intelligence-api

#### testnet bootnodes
- moc

#### tesnet validator 1
- openethereum
- app interact consensus

#### tesnet validator 2
- openethereum

#### mainnet dapps + rpc
- blockscout
- rpc
- status
- faucet
- visualizer (v5)

## Docker info

### blockscout
- image:
  - v4.1.8: hexpm/elixir:1.13.4-erlang-24.1.3-alpine-3.16.0
  - v5.2.2: hexpm/elixir:1.14.5-erlang-24.2.2-alpine-3.16.0

### db
- image:
  - v4.1.8: postgres:11
  - v5.2.2: postgres:12

### nginx
- image: nginx

### traefik
- image: traefik:v3.3
- compose: `compose-dapps-traefik-v4.yml`, `compose-dapps-traefik-v5.yml`
- docs: [traefik.md](../docs/traefik.md)

### frontend
- image: