#!/usr/bin/env bash

# This file specifies a chart, chart version, release name, and a file from where take variables from

chart_to_deploy="onedata/cross-support-job-3p"
version="0.2.5"

if [[ $release_name != "" ]]; then
    release_name="-n $release_name"
fi

if [[ $helm_dry_run != "" ]]; then
    helm_dry_run="--dry-run"
fi

if [[ $helm_debug != "" ]]; then
    helm_debug="--debug"
fi

echo helm install $helm_dry_run --timeout 480 $helm_debug --namespace $namespace $release_name -f ~/landscapes/$landscape/landscape.yaml "$chart_to_deploy" --version $version
cat ~/landscapes/$landscape/landscape.yaml
helm install $helm_dry_run --timeout 480 $helm_debug --namespace $namespace $release_name -f ~/landscapes/$landscape/landscape.yaml "$chart_to_deploy" --version $version
