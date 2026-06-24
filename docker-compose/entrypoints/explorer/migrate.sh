#!/bin/bash
mix do ecto.create --no-compile, ecto.migrate --no-compile && echo "migrated DB"