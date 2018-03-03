#!/bin/bash

if [ "$INITDB" = "True" ]; then
    airflow initdb
else
    sleep "${START_DELAY:-1}"
fi