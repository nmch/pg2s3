#!/bin/bash
set -e -o pipefail

execute_backup(){
  DBNAME=$1
  if [[ ${DBNAME} == "" ]]; then
    echo "empty database name"
    exit 1
  fi

  if [[ ${DBNAME} == "template1"  || ${DBNAME} == "postgres" || ${DBNAME} == "rdsadmin" ]]; then
    return
  fi

  DUMP_FILENAME="${DBNAME}.custom.dump"

  CURRENT_DATE="$(date)";
  echo "Backup ${DBNAME} started at ${CURRENT_DATE}"

  mkdir -p ${DUMP_DIR}
  TMP_DUMP_FILEPATH="${DUMP_DIR}/dump.tmp"

  DUMP_FILENAME_LIST=("${DBNAME}.custom.dump")

  if [[ ${HISTORY} == "HDM" ]]; then
    HOUR=`date +%H`
    DATE=`date +%d`
    MONTH=`date +%m`

    DUMP_FILENAME_LIST+=("${DBNAME}.h${HOUR}.custom.dump")
    DUMP_FILENAME_LIST+=("${DBNAME}.d${DATE}.custom.dump")
    DUMP_FILENAME_LIST+=("${DBNAME}.m${MONTH}.custom.dump")
  elif [[ ${HISTORY} == "SEQ" ]]; then
    SEQ=`date +%Y%m%d%H%M%S`
    DUMP_FILENAME_LIST+=("${DBNAME}.${SEQ}.custom.dump")
  fi

  pg_dump -Fc -f ${TMP_DUMP_FILEPATH} ${DBNAME} || exit $?
  ls -la ${TMP_DUMP_FILEPATH}
  MD5=$(md5sum "${TMP_DUMP_FILEPATH}")
  echo "MD5: ${MD5}"

  for i in ${!DUMP_FILENAME_LIST[@]}
  do
    DUMP_FILENAME=${DUMP_FILENAME_LIST[$i]}
    DUMP_FILEPATH="${DUMP_DIR}/${DUMP_FILENAME}"
    MD5_FILEPATH="${DUMP_FILEPATH}.md5"
    echo "DUMP FILE(${i}): ${DUMP_FILEPATH}"

    cp ${TMP_DUMP_FILEPATH} ${DUMP_FILEPATH}
    echo ${MD5} > ${MD5_FILEPATH}

    if [[ ${S3_PATH} != "**None**" ]]; then
      aws s3 cp --no-progress "${DUMP_FILEPATH}" "${S3_PATH}"
      aws s3 cp --no-progress "${DUMP_FILEPATH}.md5" "${S3_PATH}"

      if [[ ${MOVE_TO_S3} == "1" ]]; then
        rm ${DUMP_FILEPATH}
        rm ${MD5_FILEPATH}
      fi
    fi
  done

  rm "${TMP_DUMP_FILEPATH}"

  CURRENT_DATE="$(date)";
  echo " finished at ${CURRENT_DATE}"
}

if [[ ${PGDATABASE} == "**None**" ]]; then
  if [[ ${ON_EXECUTE_DISCONNECT} == "force" ]]; then
    psql -c "select pg_terminate_backend(pid) from pg_stat_activity where pid <> pg_backend_pid() and usename = '${PGUSER}'" template1
  fi
  DATABASES=$(psql -qAt -c 'select datname from pg_database where datallowconn' template1)
  for DBNAME in ${DATABASES}; do
    execute_backup "${DBNAME}"
  done
else
  if [[ ${ON_EXECUTE_DISCONNECT} == "force" ]]; then
    psql -c "select pg_terminate_backend(pid) from pg_stat_activity where pid <> pg_backend_pid() and usename = '${PGUSER}' and datname = '${PGDATABASE}'" template1
  fi
  execute_backup "${PGDATABASE}"
fi
