#!/bin/bash
set -e

imageTests+=(
    [z0beat/airflow]='
        airflow-run
    '
)