#!/bin/bash

if [ "$DEBUG" = "True" ]; then
    set -x
fi

if [ "${AIRFLOW_AUTOCONF}" = "True" ]; then
    for configuration_script in ${AIRFLOW_CONF}/*
    do
        source $configuration_script
    done
fi

exec "$@"
