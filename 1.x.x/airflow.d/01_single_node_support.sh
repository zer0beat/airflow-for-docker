#!/bin/bash

if [ "$SINGLE_NODE" = "True" ]; then
    airflow initdb
    airflow scheduler &
fi