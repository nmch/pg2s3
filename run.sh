#!/bin/sh -eu

if [ "${SCHEDULE}" = "**None**" ]; then
  bash backup.sh
else
  exec go-cron "${SCHEDULE}" /bin/sh backup.sh
fi
