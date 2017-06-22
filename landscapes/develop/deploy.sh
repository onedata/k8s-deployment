#!/usr/bin/env bash

# This file specifies a chart, chart version, release name, and a file from where take variables from
echo helm install --dry-run --debug --namespace $NAMESPACE -n $RELEASE_NAME -f /root/landscapes/develop/cross-support-job-3p.yaml onedata/cross-support-job-3p
cat landscapes/develop/cross-support-job-3p.yaml
helm install --wait --timeout 480 --debug --namespace $NAMESPACE -n $RELEASE_NAME -f /root/landscapes/develop/cross-support-job-3p.yaml onedata/cross-support-job-3p