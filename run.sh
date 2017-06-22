#!/usr/bin/env bash

if [[ -z $KUBE_CONFIG ]] ; then KUBE_CONFIG=~/.kube/config ; fi

export KUBE_CONFIG="$KUBE_CONFIG"
export NAMESPACE=$NAMESPACE
export RELEASE_NAME=$RELEASE_NAME
export OZ_IMAGE=$OZ_IMAGE
export OP_IMAGE=$OP_IMAGE
export OC_IMAGE=$OC_IMAGE
export CLI_IMAGE=$CLI_IMAGE

type docker-compose >/dev/null 2>&1 || {
    echo >&2 "I require docker-compose but it's not installed. Downloading..." ;
    curl -L https://github.com/docker/compose/releases/download/1.13.0/docker-compose-`uname -s`-`uname -m` > docker-compose
    chmod +x docker-compose
    export PATH=$PATH:.
}

docker-compose -f docker/docker-compose.yaml config
docker-compose -f docker/docker-compose.yaml up --remove-orphans

ls docker-compose 2>&1 && rm docker-compose