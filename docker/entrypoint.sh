#!/usr/bin/env bash
# In this script we first delete any previous deployment
# then create a new one in its place

# TODO: add to container
# echo "Downloading kubectl"
# curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.6.3/bin/linux/amd64/kubectl
# mv ./kubectl /bin

# If no namespace was given lets use one from the config
# TODO: make sure they fix this to be default
# https://github.com/Eneco/landscaper/issues/81
if [[ "$NAMESPACE" == "" ]]; then
  NAMESPACE=$(kubectl config get-contexts 2>&1 | grep -e "^\*" | tr -s ' ' |   cut -d ' '  -f 5)
fi

helm repo add onedata https://groundnuty.github.io/onedata-charts/

if [[ $RELEASE_NAME != "" ]] ; then
  RELEASE_NAME=$RELEASE_NAME
  # Clear the namespace
  echo "Removing previous deployment"
  #landscaper apply --namespace $NAMESPACE --no-prefix --dir /landscapes/
  helm delete --purge $RELEASE_NAME
  helm search cross
  helm search onedata
else
  echo "No RELEASE_NAME specified, no cleaning of previous releases is done"
fi

echo "Starting to wait for all pods except for oneprovider to exit"
while kubectl -n $NAMESPACE get pods -o name | grep -v '\-oneprovider' ; do
  sleep 1 ;
  echo "Waiting for all pods except oneproviders to exit"
done

echo "Terminating all remaining pods"
# TODO: NFS makes it impossible for provider pods to terminate normally
kubectl -n $NAMESPACE get pod  | grep Terminating | cut -d ' ' -f 1 | xargs -I{}  kubectl -n $NAMESPACE delete  --grace-period=0 --force pod  {}

echo "Waiting for pods to terminate"
# Lets be sure, this namespace is empty
output="" ;
while [[ "$output" != "No resources found." ]] ; do
  output=$(kubectl -n $NAMESPACE  get pod 2>&1)
  echo "Waiting for the NAMESPACE=$NAMESPACE to be empty"
  sleep 3
done

# Modify deployment
## Thanks to the fact how yaml is parsed, in order to override images
## we just need to append the same values to the end of the file
cp -r /landscapes /root/
echo "" >> /root/landscapes/develop/cross-support-job-3p.yaml
if [[ "$OZ_IMAGE" != "" ]]; then
  echo "  oz_image: &oz_image $OZ_IMAGE" >> /root/landscapes/develop/cross-support-job-3p.yaml
fi
if [[ "$OP_IMAGE" != "" ]]; then
  echo "  op_image: &op_image $OP_IMAGE" >> /root/landscapes/develop/cross-support-job-3p.yaml
fi
if [[ "$OC_IMAGE" != "" ]]; then
  echo "  oc_image: &oc_image $OC_IMAGE" >> /root/landscapes/develop/cross-support-job-3p.yaml
fi
if [[ "$CLI_IMAGE" != "" ]]; then
  echo "  cli_image: &cli_image $CLI_IMAGE" >> /root/landscapes/develop/cross-support-job-3p.yaml
fi

# Create new deployment
export NAMESPACE=$NAMESPACE
export RELEASE_NAME=$RELEASE_NAME
/root/landscapes/develop/deploy.sh
