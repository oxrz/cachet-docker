#!/bin/bash
set -o errexit -o nounset -o pipefail

[ "${DEBUG:-false}" == true ] && set -x

chk_db_conn() {
  echo "Attempting to connect to database for [${DB_CONNECTION}] ..."
  case "${DB_CONNECTION}" in
    pgsql)
      prog="/usr/bin/pg_isready"
      prog="${prog} -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USERNAME} -d ${DB_DATABASE} -t 1"
      ;;
    sqlite)
      prog="touch ${DB_PATH}"
  esac
  timeout=60
  while ! ${prog} >/dev/null 2>&1
  do
    timeout=$(( timeout - 1 ))
    if [[ "$timeout" -eq 0 ]]; then
      echo
      echo "Could not connect to database server! Aborting..."
      exit 1
    fi
    echo -n "."
    sleep 1
  done
  echo
}

chk_db_init() {
  table=sessions
  case "${DB_CONNECTION}" in
    pgsql)
      #chk_pgsql
      export PGPASSWORD=${DB_PASSWORD}
      if [[ "$(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USERNAME}" -d "${DB_DATABASE}" -c "SELECT to_regclass('${table}');" | grep -c "${table}")" -eq 1 ]]; then
        echo "Table ${table} exists! ..."
      else
        echo "Table ${table} does not exist! ..."
        migrate_db
      fi
      ;;
    sqlite)
      #chk_sqlite
      if [[ "$(sqlite3 ${DB_PATH} "SELECT EXISTS (SELECT * FROM sqlite_master WHERE type='table' AND name='${table}');")" -eq 1 ]]; then
        echo "Table ${table} exists! ..."
      else
        echo "Table ${table} does not exist! ..."
        migrate_db
      fi
  esac
}

init_env() {
  DB_CONNECTION=${DB_CONNECTION:-}
  echo "Initializing Cachet container for [${DB_CONNECTION}] ... "

  if [[ "${DB_CONNECTION}" = "pgsql" ]]; then
    DB_PORT=${DB_PORT:-5432}
    DB_HOST=${DB_HOST:-postgres}
    DB_DATABASE=${DB_DATABASE}
    DB_USERNAME=${DB_USERNAME}
    DB_PASSWORD=${DB_PASSWORD}
  elif [[ "${DB_CONNECTION}" = "sqlite" ]]; then
    DB_DATABASE=""
    DB_HOST=""
    DB_PORT=""
    DB_USERNAME=""
    DB_PASSWORD=""
  fi

  CACHE_DRIVER=${CACHE_DRIVER:-apc}
  GITHUB_TOKEN=${GITHUB_TOKEN:-}
}


migrate_db() {
  force=""
  if [[ "${FORCE_MIGRATION:-false}" == true ]]; then
    force="--force"
  fi
  php artisan migrate ${force}
}


start_system() {
  init_env
  php artisan vendor:publish --tag=cachet
  
  chk_db_conn
  chk_db_init

  echo "Starting Cachet ..."
  cd /app/public && php -S ${SERVER_IP:-0.0.0.0}:${SERVER_PORT:-8000}
}

start_system

exit 0