#!/bin/bash

#### Utils
function throw {
    echo $1
    exit 1
}

function export_airflow_variables {
    for var in $(set | grep AIRFLOW__ | grep -v REMOVE_THIS_FROM_RESULT); do
        export ${var}
    done
}

function file_env {
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
function wait_for_port {
  local name="${1}" host="${2}" port="${3}"
  local j=0
  while ! nc -z "${host}" "${port}" >/dev/null 2>&1 < /dev/null; do
    j=$((j+1))
    if [ "$j" -ge 12 ]; then
      throw "$(date) - ${host}:${port} still not reachable, giving up"
    fi
    echo "$(date) - waiting for ${name} (${host}:${port})... ${j}/${TRY_LOOP}"
    sleep 5
  done
}

#### Backend
function get_sql_alchemy_conn {
    local __resultvar=$1
    local selected_backend=${2:-sqlite}
    if is_a_supported_backend "$selected_backend"; then
        get_sql_alchemy_conn_$selected_backend "sql_alchemy_conn"
        eval $__resultvar="'$sql_alchemy_conn'"
        return
    fi
    throw "Backend ${selected_backend} is not supported"
}

function is_a_supported_backend {
    local selected_backend=${1}
    local supported_backends="sqlite mysql postgres"
    for supported_backend in $supported_backends; do
        if [ "$selected_backend" = "$supported_backend" ]; then
            return 0
        fi
    done
    return 1
}

function get_sql_alchemy_conn_mysql {
    local __resultvar=$1
    file_env 'BACKEND_USER'
    file_env 'BACKEND_PASSWORD'
    file_env 'BACKEND_HOST'
    file_env 'BACKEND_PORT'
    file_env 'BACKEND_DATABASE'
    if [ -z "${BACKEND_USER}" -o -z "${BACKEND_PASSWORD}" -o -z "${BACKEND_HOST}" -o -z "${BACKEND_PORT}" -o -z "${BACKEND_DATABASE}" ]; then
        throw "Incomplete MySQL configuration. Variables BACKEND_USER, BACKEND_PASSWORD, BACKEND_HOST, BACKEND_PORT, BACKEND_DATABASE are needed."
    fi
    wait_for_port "MySQL" "${BACKEND_HOST}" "${BACKEND_PORT}"
    eval $__resultvar="'mysql+mysqldb://${BACKEND_USER}:${BACKEND_PASSWORD}@${BACKEND_HOST}/${BACKEND_DATABASE}'"
}

function get_sql_alchemy_conn_postgres {
    local __resultvar=$1
    file_env 'BACKEND_USER'
    file_env 'BACKEND_PASSWORD'
    file_env 'BACKEND_HOST'
    file_env 'BACKEND_PORT'
    file_env 'BACKEND_DATABASE'
    if [ -z "${BACKEND_USER}" -o -z "${BACKEND_PASSWORD}" -o -z "${BACKEND_HOST}" -o -z "${BACKEND_PORT}" -o -z "${BACKEND_DATABASE}" ]; then
        throw "Incomplete Postgres configuration. Variables BACKEND_USER, BACKEND_PASSWORD, BACKEND_HOST, BACKEND_PORT, BACKEND_DATABASE are needed."
    fi
    wait_for_port "Postgres" "${BACKEND_HOST}" "${BACKEND_PORT}"
    eval $__resultvar="'postgresql+psycopg2://${BACKEND_USER}:${BACKEND_PASSWORD}@${BACKEND_HOST}:${BACKEND_PORT}/${BACKEND_DATABASE}'"
}

function get_sql_alchemy_conn_sqlite {
    local __resultvar=$1
    INITDB=${INITDB:-True}
    RUN_AIRFLOW_SCHEDULER=${RUN_AIRFLOW_SCHEDULER:-True}
    eval $__resultvar="'sqlite:////${AIRFLOW_HOME}/airflow.db'"
}

#### Executor
function get_executor {
    local __resultvar=$1
    local selected_executor=${2:-SequentialExecutor}
    local supported_executors="SequentialExecutor LocalExecutor CeleryExecutor"
    for supported_executor in $SUPPORTED_EXECUTORS; do
        if [ "$selected_executor" = "$supported_executor" ]; then
            eval $__resultvar="'$selected_executor'"
            return
        fi
    done
    throw "Executor ${selected_executor} is not supported"
}

#### Celery
function get_celery_broker_url {
    local __resultvar=$1
    local selected_celery_broker=${2:-rabbitmq}
    if is_a_supported_celery_broker "$selected_celery_broker"; then
        get_celery_broker_url_$selected_celery_broker "celery_broker_url"
        eval $__resultvar="'$celery_broker_url'"
        return
    fi
    throw "Celery broker ${selected_celery_broker} is not supported"

function is_a_supported_celery_broker {
    local selected_celery_broker=${1}
    local supported_celery_brokers="redis rabbitmq"
    for supported_celery_broker in $supported_celery_brokers; do
        if [ "$selected_celery_broker" = "$supported_celery_broker" ]; then
            return 0
        fi
    done
    return 1
}

function get_celery_broker_url_redis {
    local __resultvar=$1
    file_env 'CELERY_BROKER_PASSWORD'
    file_env 'CELERY_BROKER_HOST'
    file_env 'CELERY_BROKER_PORT'
    if [ -z "${CELERY_BROKER_HOST}" -o -z "${CELERY_BROKER_PORT}" ]; then
        throw "Incomplete Redis configuration. Variables CELERY_BROKER_HOST, CELERY_BROKER_PORT are needed."
    fi
    wait_for_port "Redis" "${CELERY_BROKER_HOST}" "${CELERY_BROKER_PORT}"
    eval $__resultvar="'redis://:${CELERY_BROKER_PASSWORD}@${CELERY_BROKER_HOST}:${CELERY_BROKER_PORT}/1'"
}

function get_celery_broker_url_rabbitmq {
    local __resultvar=$1
    file_env 'CELERY_BROKER_USER'
    file_env 'CELERY_BROKER_PASSWORD'
    file_env 'CELERY_BROKER_HOST'
    file_env 'CELERY_BROKER_PORT'
    if [ -z "${CELERY_BROKER_USER}" -o -z "${CELERY_BROKER_PASSWORD}" -o -z "${CELERY_BROKER_HOST}" -o -z "${CELERY_BROKER_PORT}" ]; then
        throw "Incomplete RabbitMQ configuration. Variables CELERY_BROKER_USER, CELERY_BROKER_PASSWORD, CELERY_BROKER_HOST, CELERY_BROKER_PORT are needed."
    fi
    wait_for_port "Redis" "${CELERY_BROKER_HOST}" "${CELERY_BROKER_PORT}"
    eval $__resultvar="'amqp://${CELERY_BROKER_USER}:${CELERY_BROKER_PASSWORD}@${CELERY_BROKER_HOST}:${CELERY_BROKER_PORT}/airflow'"
}

function get_celery_result_backend {
    if [ "$BACKEND" = "mysql" ]; then
        echo db+mysql://${BACKEND_USER}:${BACKEND_PASSWORD}@${BACKEND_HOST}/${BACKEND_DATABASE}
    elif [ "$BACKEND" = "postgres" ]; then
        echo db+postgresql://${BACKEND_USER}:${BACKEND_PASSWORD}@${BACKEND_HOST}:${BACKEND_PORT}/${BACKEND_DATABASE}
    fi
}

#### Main
if [ "$DEBUG" = "True" ]; then
    set -x
fi

AIRFLOW__CORE__LOAD_EXAMPLES=${LOAD_EXAMPLES:-False}
AIRFLOW__CORE__AIRFLOW_HOME=${AIRFLOW_HOME}
AIRFLOW__CORE__FERNET_KEY=${FERNET_KEY:=$(python -c "from cryptography.fernet import Fernet; FERNET_KEY = Fernet.generate_key().decode(); print(FERNET_KEY)")}
get_sql_alchemy_conn "AIRFLOW__CORE__SQL_ALCHEMY_CONN" "$BACKEND"
get_executor "AIRFLOW__CORE__EXECUTOR" "$EXECUTOR"

if [ "$AIRFLOW__CORE__EXECUTOR" = "CeleryExecutor" ]; then
    get_celery_broker_url "AIRFLOW__CELERY__BROKER_URL" "$BROKER"
    AIRFLOW__CELERY__CELERY_RESULT_BACKEND=$(get_celery_result_backend)
    wait_for_port "${CELERY_BROKER}" "${CELERY_BROKER_HOST}" "${CELERY_BROKER_PORT}"
fi

export_airflow_variables

if [ "$INITDB" = "True" ]; then
    airflow initdb
else
    sleep 15
fi

if [ "$RUN_AIRFLOW_SCHEDULER" = "True" ]; then
    airflow scheduler &
fi

exec "$@"
