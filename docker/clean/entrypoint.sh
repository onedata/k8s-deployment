#!/usr/bin/env bash
# This script deletes helm release from the cluster if their label `deathtime` is smaller then the current time 

was_anything_found=false
while read release_name deathtime ; do
  was_anything_found=true

  # For some reason buysbox date does not want to parse timezone when present in input date
  deathtime_seconds=$(date -D "%a %b %d %H:%M:%S %Y" -d "`echo $deathtime | tr '_' ' ' | tr '-' ':' | rev | cut -d ' ' -f2- | rev`" +"%s")
  current_time_seconds=$(date +"%s")

  if [[ $current_time_seconds -gt $deathtime_seconds ]] ; then
    echo "Deathtime of release $release_name was set to $deathtime, deleting..."
    if ! $dry_run ; then
      if [[ $release_name != "" ]] ; then
        release_name=$release_name
        # Clear the namespace
        echo "Removing deployment: $release_name"
        #landscaper apply --namespace $namespace --no-prefix --dir /landscapes/
        helm delete --purge $release_name
        helm search cross
        helm search onedata
      else
        echo "No release_name specified, no cleaning of previous releases is done"
      fi

      echo "Starting to wait for all pods except for oneprovider to exit"
      while kubectl -n $namespace get pods -o name | grep -v '\-oneprovider' ; do
        sleep 1 ;
        echo "Waiting for all pods except oneproviders to exit"
      done

      echo "Terminating all remaining pods"
      # TODO: NFS makes it impossible for provider pods to terminate normally
      kubectl get pods --all-namespaces | grep Terminating | tr -s ' ' | cut -d ' ' -f1,2 | while read namespace pod ; do kubectl -n $namespace delete  --grace-period=0 --force pod $pod ; done
    fi
  else
    echo "Release $release_name may live, deathtime set to $deathtime."
  fi
done < <(kubectl -n kube-system get cm --selector=deathtime -o go-template='{{- if .items -}}
  {{- if gt (len .items) 0}}
    {{- range .items -}}
      {{- printf "%s %s\n" .metadata.labels.NAME .metadata.labels.deathtime }}
    {{- end -}}
  {{- end -}}
{{- else -}}
  {{- printf "" -}}
{{- end -}}')

if ! $was_anything_found ; then
  echo "There are no release with label 'deathtime'" ;
fi