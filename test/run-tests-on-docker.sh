#!/bin/bash

if uname -a | grep Darwin &>/dev/null; then
    PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"
fi

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

self="$(basename "$0")"

usage() {
	cat <<EOUSAGE
usage: $self image:tag
   ie: $self z0beat/airflow:1.9.0

This script processes the specified Docker images to test their running
environments.
EOUSAGE
}

image=$1
if [ -z "$image" ]; then
    usage
    exit 1
fi

if ! docker inspect "$image" &> /dev/null; then
    echo "image $image does not exist!"
    exit 1
fi

DOCKER_VERSION=$(docker version --format '{{.Client.Version}}')
DOCKER_IMAGE=docker:${DOCKER_VERSION}-git

echo "Running tests for $image on $DOCKER_IMAGE image"
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v $dir/../:/data -w /data/test $DOCKER_IMAGE ./run-tests-docker-wrapper.sh $image