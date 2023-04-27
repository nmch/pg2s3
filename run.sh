#!/bin/sh -eu

if [ "${SCHEDULE}" = "**None**" ]; then
  bash backup.sh
else
  exec go-cron "${SCHEDULE}" bash backup.sh
fi
