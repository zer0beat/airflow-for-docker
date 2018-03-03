#!/bin/bash
set -Eeuo pipefail

AIRFLOW_IMAGE=$1

hash=$(docker run -d --rm -e SINGLE_NODE=True $AIRFLOW_IMAGE airflow webserver)
trap "docker kill $hash > /dev/null" EXIT

docker exec $hash wget -t 5 -qO- http://localhost:8080/admin/versionview/ | grep "Version : <a"
