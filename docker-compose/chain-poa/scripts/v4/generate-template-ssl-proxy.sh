#!/bin/bash
docker compose -f compose-dapps-v4.yml run --rm --entrypoint ./docker-entrypoint.d/20-envsubst-on-templates.sh -e NGINX_ENVSUBST_TEMPLATE_SUFFIX=.ssl-template nginx