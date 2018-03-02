#!/bin/bash

if [ "$DEBUG" = "True" ]; then
    set -x
fi

for configuration_Script in ${AIRFLOW_CONF}/*
do
    source $configuration_Script
done

exec "$@"
