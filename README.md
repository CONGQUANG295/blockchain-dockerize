# BlockChain Docker Integration

## Requiremnets
- Docker Compose 2.20.3+
- Bash

## Chain
- [POA](./docs/poa.md)
- [DPOS](./docs/dpos.md)

## Proxy
- [Nginx (legacy)](./docs/proxy.md)
- [Traefik](./docs/traefik.md)

## Quick commands (Makefile)

From monorepo root (`blockchain-dock/`):

```bash
make dpos help
make dpos deploy WITH_TRAEFIK=1
make poa help
make poa validator-1-up
make build build-chain
```

See [docs/makefile.md](./docs/makefile.md).
