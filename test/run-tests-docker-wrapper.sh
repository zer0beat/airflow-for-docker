#!/bin/sh

image="$1"

apk update &> /dev/null
apk add bash &> /dev/null
./run-tests.sh "$image"