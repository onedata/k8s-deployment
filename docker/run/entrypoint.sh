#!/usr/bin/env bash
# In this script we first delete any previous deployment
# then create a new one in its place

# If we want to use local helm repo in a container we need to fix paths to local repo
if [[ -d ~/.helm_ro ]]; then
  rm -rf ~/.helm
  cp -r ~/.helm_ro ~/.helm
  sed -i 's#\(cache: \).*\(.helm.*\)#\1/root/\2#g'  ~/.helm/repository/repositories.yaml
  rm ~/.helm/repository/cache/local-index.yaml
  ln -s ~/.helm/repository/local/index.yaml ~/.helm/repository/cache/local-index.yaml

  helm serve ~/charts/ &
fi

# If no namespace was given lets use one from the config
# TODO: make sure they fix this to be default
# https://github.com/Eneco/landscaper/issues/81
if [[ "$namespace" == "" ]]; then
  namespace=$(kubectl config get-contexts 2>&1 | grep -e "^\*" | tr -s ' ' |   cut -d ' '  -f 5)
fi

helm repo add onedata https://onedata.github.io/charts/

if [[ $release_name != "" ]] ; then
  release_name=$release_name
  # Clear the namespace
  release_present=$(helm ls $release_name)
  if [[ "$release_present" != "" ]]; then
    echo "Removing previous deployment: $release_name"
    #landscaper apply --namespace $namespace --no-prefix --dir /landscapes/
    helm delete --purge $release_name
  else
    echo "Release $release_name does not exist."
  fi
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
kubectl -n $namespace get pod  | grep Terminating | cut -d ' ' -f 1 | xargs -I{}  kubectl -n $namespace delete  --grace-period=0 --force pod  {}

echo "Waiting for pods to terminate"
# Lets be sure, this namespace is empty
output="" ;
while [[ "$output" != "No resources found." ]] ; do
  output=$(kubectl -n $namespace  get pod 2>&1)
  echo "Waiting for the namespace=$namespace to be empty"
  sleep 3
done

# Modify deployment
## Thanks to the fact how yaml is parsed, in order to override images
## we just need to append the same values to the end of the file
cp -r /landscapes /root/
landscae_path="/root/landscapes/$landscape/landscape.yaml"
echo "" >> "$landscae_path"
if [[ "$oz_image" != "" ]]; then
  echo "  oz_image: &oz_image $oz_image" >> "$landscae_path"
fi
if [[ "$op_image" != "" ]]; then
  echo "  op_image: &op_image $op_image" >> "$landscae_path"
fi
if [[ "$oc_image" != "" ]]; then
  echo "  oc_image: &oc_image $oc_image" >> "$landscae_path"
fi
if [[ "$cli_image" != "" ]]; then
  echo "  cli_image: &cli_image $cli_image" >> "$landscae_path"
fi

# Create new deployment
export namespace=$namespace
export release_name=$release_name
export helm_dry_run=$helm_dry_run
export helm_debug=$helm_debug
export landscape=$landscape

/root/landscapes/$landscape/deploy.sh

# Set time when this build can be garbage collected
deathtime=$(date +"%a_%b_%d_%H-%M-%S_%Y_%Z" @$(( `date +%s`+3600*${lifetime} )))
echo "Setting label deathtime=$deathtime on this release"
kubectl -n kube-system label cm -lNAME=$release_name  deathtime="$deathtime" --overwrite

# Set release owner
echo "Setting label release-owner="$user" on this release"
kubectl -n kube-system label cm -lNAME=$release_name  release-owner="$user" --overwrite