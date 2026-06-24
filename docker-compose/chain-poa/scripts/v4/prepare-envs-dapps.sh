#!/bin/bash
if [ ! -f 'envs/poa.env' ]; then
  cp envs/poa.env.example envs/poa.env
fi

if [ ! -e envs/db.env ]; then
  cp envs/db.env.example envs/db.env
fi

if [ ! -e envs/blockscout.env ]; then
  cp envs/blockscout.env.example envs/blockscout.env
fi

if [ ! -e envs/eth-faucet.env ]; then
  cp envs/eth-faucet.env.example envs/eth-faucet.env
fi

if [ ! -e envs/netstats-dashboard.env ]; then
  cp envs/netstats-dashboard.env.example envs/netstats-dashboard.env
fi

if [ ! -e envs/netstats-api.env ]; then
  cp envs/netstats-api.env.example envs/netstats-api.env
fi

if [ ! -e envs/docs.env ]; then
  cp envs/docs.env.example envs/docs.env
fi

if [ ! -e envs/nginx.env ]; then
  cp envs/nginx.env.example envs/nginx.env
fi