#!/bin/bash
if [ ! -f 'envs/poa.env' ]; then
  cp envs/poa.env.example envs/poa.env
fi

if [ ! -e envs/validator-2.env ]; then
  cp envs/validator-2.env.example envs/validator-2.env
fi