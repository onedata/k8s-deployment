#!/usr/bin/env bash

# This file specifies a chart, chart version, release name, and a file from where take variables from

cat landscapes/develop/cross-support-job-3p.yaml

if [[ $RELEASE_NAME != "" ]]; then
    RELEASE_NAME="-n $RELEASE_NAME"
fi

echo helm install --dry-run --debug --namespace $NAMESPACE $RELEASE_NAME -f /root/landscapes/develop/cross-support-job-3p.yaml onedata/cross-support-job-3p
helm install --wait --timeout 480 --debug --namespace $NAMESPACE $RELEASE_NAME -f /root/landscapes/develop/cross-support-job-3p.yaml onedata/cross-support-job-3p
