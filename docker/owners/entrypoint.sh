#!/usr/bin/env bash
# This script prints a table of release names and it's owners based on release config-map labels

kubectl -n kube-system get cm -lOWNER=TILLER,STATUS=DEPLOYED -o go-template='{{- if .items -}}
  {{- if gt (len .items) 0}}
    {{- $name := (printf "%s%40s" "NAME" " ") -}}
    {{- $releaseowner := (printf "%s%40s" "OWNER" " ") -}}
    {{- printf "%.40s%.40s\n" $name $releaseowner }}
    {{- range .items -}}
      {{- $name := (printf "%s%40s" .metadata.labels.NAME " ") -}}
      {{- $releaseowner := (printf "%s%40s" ( index .metadata.labels "release-owner" ) " ") -}}
      {{- printf "%.40s%.40s\n" $name $releaseowner }}
    {{- end -}}
  {{- end -}}
{{- else -}}
  {{- printf "No resources found.\n" -}}
{{- end -}}'