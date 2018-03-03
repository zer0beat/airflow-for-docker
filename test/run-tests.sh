#!/bin/bash

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"
self="$(basename "$0")"
official_images_dir="$dir/../official-images"

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

if [ ! -d "$official_images_dir" ]; then
    git clone https://github.com/docker-library/official-images.git $official_images_dir &> /dev/null
else
    pushd $official_images_dir &> /dev/null
    git pull &> /dev/null
    popd &> /dev/null
fi

$official_images_dir/test/run.sh \
    --config $official_images_dir/test/config.sh \
    --config $dir/airflow_config.sh \
    "$image"