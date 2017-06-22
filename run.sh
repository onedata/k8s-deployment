#!/usr/bin/env bash

if [[ -z $KUBE_CONFIG ]] ; then KUBE_CONFIG=~/.kube/config ; fi

export KUBE_CONFIG="$KUBE_CONFIG"
export NAMESPACE=$NAMESPACE
export RELEASE_NAME=$RELEASE_NAME
export OZ_IMAGE=$OZ_IMAGE
export OP_IMAGE=$OP_IMAGE
export OC_IMAGE=$OC_IMAGE
export CLI_IMAGE=$CLI_IMAGE

docker-compose -f docker/docker-compose.yaml config
docker-compose -f docker/docker-compose.yaml up --remove-orphans