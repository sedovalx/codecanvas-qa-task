#!/usr/bin/env bash

if [ "${#@}" -eq 0 ]; then
  echo "Please pass a command: codecanvas-up or codecanvas-down"
  exit 0
else
  exec "$@"
fi

