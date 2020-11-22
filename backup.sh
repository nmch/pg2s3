#!/bin/sh
set -e -o pipefail

execute_backup(){
  if [ "${DBNAME}" = "template1" ] || [ "${DBNAME}" = "postgres" ] || [ "${DBNAME}" = "rdsadmin" ]; then
    return
  fi

  DBNAME=$1
  if [ "${DBNAME}" = "" ]; then
    echo "empty database name"
    exit 1
  fi

  DUMP_FILENAME="${DBNAME}.custom.dump"

  CURRENT_DATE="$(date)";
  echo "Backup ${DBNAME} started at ${CURRENT_DATE}"

  mkdir -p ${DUMP_DIR}
  DUMP_FILEPATH="${DUMP_DIR}/${DUMP_FILENAME}"
  TMP_DUMP_FILEPATH="${DUMP_DIR}/dump.tmp"

  pg_dump -Fc -f "${TMP_DUMP_FILEPATH}" "${DBNAME}" || exit $?
  mv "${TMP_DUMP_FILEPATH}" "${DUMP_FILEPATH}"

  echo "${DBNAME} dumped to ${DUMP_FILEPATH}"
  ls -la "${DUMP_FILEPATH}"
  MD5=$(md5sum "${DUMP_FILEPATH}")
  echo "MD5: ${MD5}"
  echo ${MD5} > ${DUMP_FILEPATH}.md5

  if [ "${S3_PATH}" != "**None**" ]; then
    aws s3 cp --no-progress "${DUMP_FILEPATH}" "${S3_PATH}"
    aws s3 cp --no-progress "${DUMP_FILEPATH}.md5" "${S3_PATH}"
  fi

  CURRENT_DATE="$(date)";
  echo " finished at ${CURRENT_DATE}"
}

if [ "${PGDATABASE}" = "**None**" ]; then
  if [ "${ON_EXECUTE_DISCONNECT}" = "force" ]; then
    psql -c "select pg_terminate_backend(pid) from pg_stat_activity where pid <> pg_backend_pid() and usename = '${PGUSER}'"
    export ON_EXECUTE_DISCONNECT="**None**"
  fi
  DATABASES=$(psql -qAt -c 'select datname from pg_database where datallowconn' template1)
  for DBNAME in ${DATABASES}; do
    execute_backup "${DBNAME}"
  done
else
  if [ "${ON_EXECUTE_DISCONNECT}" = "force" ]; then
    psql -c "select pg_terminate_backend(pid) from pg_stat_activity where pid <> pg_backend_pid() and usename = '${PGUSER}' and datname = '${PGDATABASE}'"
  fi
  execute_backup "${PGDATABASE}"
fi
