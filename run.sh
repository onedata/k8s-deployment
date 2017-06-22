#!/usr/bin/env bash

if [[ -z $KUBE_CONFIG ]] ; then KUBE_CONFIG=~/.kube/config ; fi

docker run --rm \
    -v $PWD/docker:/docker:ro \
    -e KUBE_CONFIG="$KUBE_CONFIG" \
    -e NAMESPACE=$NAMESPACE \
    -e RELEASE_NAME=$RELEASE_NAME \
    -e OZ_IMAGE=$OZ_IMAGE \
    -e OP_IMAGE=$OP_IMAGE \
    -e OC_IMAGE=$OC_IMAGE \
    -e CLI_IMAGE=$CLI_IMAGE \
    docker/compose:1.14.0 -f docker/docker-compose.yaml config

docker run \
    -v "/var/run/docker.sock:/var/run/docker.sock" \
    -v $PWD/docker:/docker \
    -v $PWD/landscapes:/landscapes \
    -e KUBE_CONFIG="$KUBE_CONFIG" \
    -e NAMESPACE=$NAMESPACE \
    -e RELEASE_NAME=$RELEASE_NAME \
    -e OZ_IMAGE=$OZ_IMAGE \
    -e OP_IMAGE=$OP_IMAGE \
    -e OC_IMAGE=$OC_IMAGE \
    -e CLI_IMAGE=$CLI_IMAGE \
    --entrypoint sh \
    -it \
    docker/compose:1.14.0 # -f docker/docker-compose.yaml up --remove-orphans