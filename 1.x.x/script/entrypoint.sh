#!/bin/bash

function throw() {
    echo $1
    exit 1
}

function export_airflow_variables() {
    for var in $(set | grep AIRFLOW__ | grep -v REMOVE_THIS_FROM_RESULT); do
        export ${var}
    done
}

function file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		throw "Both $var and $fileVar are set (but are exclusive)"
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

# Credits to https://github.com/puckel/docker-airflow/blob/master/script/entrypoint.sh#L45-L57
wait_for_port() {
  local name="${1}" host="${2}" port="${3}"
  local j=0
  while ! nc -z "${host}" "${port}" >/dev/null 2>&1 < /dev/null; do
    j=$((j+1))
    if [ "$j" -ge 12 ]; then
      throw "$(date) - ${host}:${port} still not reachable, giving up"
    fi
    echo "$(date) - waiting for ${name}... ${j}/${TRY_LOOP}"
    sleep 5
  done
}

RUN_AIRFLOW_SCHEDULER=False
INITDB=${INITDB:-False}

AIRFLOW__CORE__LOAD_EXAMPLES=${LOAD_EXAMPLES:-False}
AIRFLOW__CORE__AIRFLOW_HOME=${AIRFLOW_HOME}
AIRFLOW__CORE__FERNET_KEY=${FERNET_KEY:=$(python -c "from cryptography.fernet import Fernet; FERNET_KEY = Fernet.generate_key().decode(); print(FERNET_KEY)")}

EXECUTOR=${EXECUTOR:-SequentialExecutor}
if [ "$EXECUTOR" = "SequentialExecutor" -o "$EXECUTOR" = "LocalExecutor" ]; then
    AIRFLOW__CORE__EXECUTOR=${EXECUTOR}
else
    throw "Executor ${EXECUTOR} is not supported"
fi
unset "EXECUTOR"

BACKEND=${BACKEND:-sqlite}
if [ "$BACKEND" = "mysql" ]; then
    file_env 'MYSQL_USER'
    file_env 'MYSQL_PASSWORD'
    file_env 'MYSQL_HOST'
    file_env 'MYSQL_PORT'
    file_env 'MYSQL_DATABASE'
    if [ -z "${MYSQL_USER}" -o -z "${MYSQL_PASSWORD}" -o -z "${MYSQL_HOST}" -o -z "${MYSQL_PORT}" -o -z "${MYSQL_DATABASE}" ]; then
        throw "Incomplete ${BACKEND} configuration. Variables MYSQL_USER, MYSQL_PASSWORD, MYSQL_HOST, MYSQL_PORT, MYSQL_DATABASE are needed."
    fi

    AIRFLOW__CORE__SQL_ALCHEMY_CONN=mysql+mysqldb://${MYSQL_USER}:${MYSQL_PASSWORD}@${MYSQL_HOST}/${MYSQL_DATABASE}
    wait_for_port "MySQL" "${MYSQL_HOST}" "${MYSQL_PORT}"
elif [ "$BACKEND" = "oracle" ]; then
    file_env 'ORACLE_USER'
    file_env 'ORACLE_PASSWORD'
    file_env 'ORACLE_HOST'
    file_env 'ORACLE_PORT'
    file_env 'ORACLE_DATABASE'
    if [ -z "${ORACLE_USER}" -o -z "${ORACLE_PASSWORD}" -o -z "${ORACLE_HOST}" -o -z "${ORACLE_PORT}" -o -z "${ORACLE_DATABASE}" ]; then
        throw "Incomplete ${BACKEND} configuration. Variables ORACLE_USER, ORACLE_PASSWORD, ORACLE_HOST, ORACLE_DATABASE are needed."
    fi
    AIRFLOW__CORE__SQL_ALCHEMY_CONN=oracle+cx_oracle://${ORACLE_USER}:${ORACLE_PASSWORD}@${ORACLE_HOST}:${ORACLE_PORT}/${ORACLE_DATABASE}
    wait_for_port "Oracle" "${ORACLE_HOST}" "${ORACLE_PORT}"
elif [ "$BACKEND" = "postgres" ]; then
    file_env 'POSTGRES_USER'
    file_env 'POSTGRES_PASSWORD'
    file_env 'POSTGRES_HOST'
    file_env 'POSTGRES_PORT'
    file_env 'POSTGRES_DATABASE'
    if [ -z "${POSTGRES_USER}" -o -z "${POSTGRES_PASSWORD}" -o -z "${POSTGRES_HOST}" -o -z "${POSTGRES_PORT}" -o -z "${POSTGRES_DATABASE}" ]; then
        throw "Incomplete ${BACKEND} configuration. Variables POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_HOST, POSTGRES_DATABASE are needed."
    fi
    AIRFLOW__CORE__SQL_ALCHEMY_CONN=postgresql+psycopg2://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DATABASE}
    wait_for_port "Postgres" "${POSTGRES_HOST}" "${POSTGRES_PORT}"
elif [ "$BACKEND" = "sqlite" ]; then
    mkdir -p /data/
    AIRFLOW__CORE__SQL_ALCHEMY_CONN=sqlite:////data/airflow.db
    INITDB=True
    RUN_AIRFLOW_SCHEDULER=True
else
    throw "Backend ${BACKEND} is not supported"
fi
unset "BACKEND"

export_airflow_variables

if [ "$INITDB" = "True" ]; then
    airflow initdb
else
    sleep 15
fi

if [ "$RUN_AIRFLOW_SCHEDULER" = "True" ]; then
    airflow scheduler &
fi

unset "INITDB"
unset "RUN_AIRFLOW_SCHEDULER"

exec "$@"
