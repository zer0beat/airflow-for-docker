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

AIRFLOW__CORE__LOAD_EXAMPLES=${LOAD_EXAMPLES:-False}
AIRFLOW__CORE__AIRFLOW_HOME=${AIRFLOW_HOME}
AIRFLOW__CORE__FERNET_KEY=${FERNET_KEY:=$(python -c "from cryptography.fernet import Fernet; FERNET_KEY = Fernet.generate_key().decode(); print(FERNET_KEY)")}

EXECUTOR=${EXECUTOR:-LocalExecutor}
if [ "$EXECUTOR" = "LocalExecutor" ]; then
    AIRFLOW__CORE__EXECUTOR=${EXECUTOR}
else
    throw "Executor ${EXECUTOR} is not supported"
fi
unset "EXECUTOR"

BACKEND=${BACKEND:-mysql}
if [ "$BACKEND" = "mysql" ]; then
    file_env 'MYSQL_USER'
    file_env 'MYSQL_PASSWORD'
    file_env 'MYSQL_HOST'
    file_env 'MYSQL_DATABASE'
    if [ -z "${MYSQL_USER}" -o -z "${MYSQL_PASSWORD}" -o -z "${MYSQL_HOST}" -o -z "${MYSQL_DATABASE}" ]; then
        throw "Incomplete ${BACKEND} configuration. Variables MYSQL_USER, MYSQL_PASSWORD, MYSQL_HOST, MYSQL_DATABASE are needed."
    fi

    AIRFLOW__CORE__SQL_ALCHEMY_CONN=mysql+mysqldb://${MYSQL_USER}:${MYSQL_PASSWORD}@${MYSQL_HOST}/${MYSQL_DATABASE}
else
    throw "Backend ${BACKEND} is not supported"
fi
unset "BACKEND"

export_airflow_variables
exec "$@"
