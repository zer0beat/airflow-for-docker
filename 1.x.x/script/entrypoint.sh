#!/bin/bash

if [ "$DEBUG" = "True" ]; then
    set -x
fi

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

function get_backend {
    local selected_backend=${BACKEND:-sqlite}
    for supported_backend in $SUPPORTED_BACKENDS; do
        if [ "$selected_backend" = "$supported_backend" ]; then
            check_backend_configuration $selected_backend
            echo $selected_backend
            return
        fi
    done
    throw "Backend ${selected_backend} is not supported"
}

function get_executor {
    local selected_executor=${EXECUTOR:-SequentialExecutor}
    for supported_executor in $SUPPORTED_EXECUTORS; do
        if [ "$selected_executor" = "$supported_executor" ]; then
            echo $selected_executor
            return
        fi
    done
    throw "Executor ${selected_executor} is not supported"
}

function get_celery_broker {
    local selected_broker=${BROKER:-rabbitmq}
    for supported_broker in $SUPPORTED_CELERY_BROKERS; do
        if [ "$selected_broker" = "$supported_broker" ]; then
            check_celery_broker_configuration $selected_broker
            echo $selected_broker
            return
        fi
    done
    throw "Celery broker ${selected_broker} is not supported"
}

function check_backend_configuration {
    local backend=$1
    if [ $backend != "sqlite" ]; then
        file_env 'BACKEND_USER'
        file_env 'BACKEND_PASSWORD'
        file_env 'BACKEND_HOST'
        file_env 'BACKEND_PORT'
        file_env 'BACKEND_DATABASE'
        if [ -z "${BACKEND_USER}" -o -z "${BACKEND_PASSWORD}" -o -z "${BACKEND_HOST}" -o -z "${BACKEND_PORT}" -o -z "${BACKEND_DATABASE}" ]; then
            throw "Incomplete ${backend} configuration. Variables BACKEND_USER, BACKEND_PASSWORD, BACKEND_HOST, BACKEND_PORT, BACKEND_DATABASE are needed."
        fi
    fi
}

function check_celery_broker_configuration {
    local broker=$1
    file_env 'CELERY_BROKER_USER'
    file_env 'CELERY_BROKER_PASSWORD'
    file_env 'CELERY_BROKER_HOST'
    file_env 'CELERY_BROKER_PORT'
    if [ "$broker" = "rabbitmq" ]; then
        if [ -z "${CELERY_BROKER_USER}" -o -z "${CELERY_BROKER_PASSWORD}" -o -z "${CELERY_BROKER_HOST}" -o -z "${CELERY_BROKER_PORT}" ]; then
            throw "Incomplete ${broker} configuration. Variables CELERY_BROKER_USER, CELERY_BROKER_PASSWORD, CELERY_BROKER_HOST, CELERY_BROKER_PORT are needed."
        fi
    elif [ "$broker" = "redis" ]; then
        if [ -z "${CELERY_BROKER_HOST}" -o -z "${CELERY_BROKER_PORT}" ]; then
            throw "Incomplete ${broker} configuration. Variables CELERY_BROKER_HOST, CELERY_BROKER_PORT are needed."
        fi
    fi
}

function get_sql_alchemy_conn {
    if [ "$BACKEND" = "mysql" ]; then
        echo mysql+mysqldb://${BACKEND_USER}:${BACKEND_PASSWORD}@${BACKEND_HOST}/${BACKEND_DATABASE}
    elif [ "$BACKEND" = "postgres" ]; then
        echo postgresql+psycopg2://${BACKEND_USER}:${BACKEND_PASSWORD}@${BACKEND_HOST}:${BACKEND_PORT}/${BACKEND_DATABASE}
    elif [ "$BACKEND" = "sqlite" ]; then
        echo sqlite:////${AIRFLOW_HOME}/airflow.db
    fi
}

function get_celery_broker_url {
    if [ "$CELERY_BROKER" = "rabbitmq" ]; then
        echo amqp://${CELERY_BROKER_USER}:${CELERY_BROKER_PASSWORD}@${CELERY_BROKER_HOST}:${CELERY_BROKER_PORT}/airflow
    elif [ "$CELERY_BROKER" = "redis" ]; then
        echo redis://:${CELERY_BROKER_PASSWORD}@${CELERY_BROKER_HOST}:${CELERY_BROKER_PORT}/1
    fi
}

function get_celery_result_backend {
    if [ "$BACKEND" = "mysql" ]; then
        echo db+mysql://${BACKEND_USER}:${BACKEND_PASSWORD}@${BACKEND_HOST}/${BACKEND_DATABASE}
    elif [ "$BACKEND" = "postgres" ]; then
        echo db+postgresql://${BACKEND_USER}:${BACKEND_PASSWORD}@${BACKEND_HOST}:${BACKEND_PORT}/${BACKEND_DATABASE}
    fi
}

INITDB=${INITDB:-False}
RUN_AIRFLOW_SCHEDULER=False
SUPPORTED_BACKENDS="sqlite mysql postgres"
SUPPORTED_EXECUTORS="SequentialExecutor LocalExecutor CeleryExecutor"
SUPPORTED_CELERY_BROKERS="redis rabbitmq"
BACKEND=$(get_backend)

AIRFLOW__CORE__LOAD_EXAMPLES=${LOAD_EXAMPLES:-False}
AIRFLOW__CORE__AIRFLOW_HOME=${AIRFLOW_HOME}
AIRFLOW__CORE__FERNET_KEY=${FERNET_KEY:=$(python -c "from cryptography.fernet import Fernet; FERNET_KEY = Fernet.generate_key().decode(); print(FERNET_KEY)")}
AIRFLOW__CORE__SQL_ALCHEMY_CONN=$(get_sql_alchemy_conn)
AIRFLOW__CORE__EXECUTOR=$(get_executor)

if [ "$BACKEND" != "sqlite" ]; then
    wait_for_port "${BACKEND}" "${BACKEND_HOST}" "${BACKEND_PORT}"
else
    INITDB=True
    RUN_AIRFLOW_SCHEDULER=True
fi

if [ "$AIRFLOW__CORE__EXECUTOR" = "CeleryExecutor" ]; then
    CELERY_BROKER=$(get_celery_broker)
    AIRFLOW__CELERY__BROKER_URL=$(get_celery_broker_url)
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
