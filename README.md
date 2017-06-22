# K8s Deployment with Helm

~~~
Export variables that you need to override (see what docker/docker-compose.yaml uses)
#export KUBE_CONFIG="$KUBE_CONFIG"
#export NAMESPACE=mwrzescz
#export RELEASE_NAME=debug-dbsync
#export OZ_IMAGE=docker.onedata.org/oneclient:ID-6a63d5d206
#export OP_IMAGE=docker.onedata.org/oneprovider:ID-947da337e0
#export OC_IMAGE=docker.onedata.org/oneclient:ID-6a63d5d206
#export CLI_IMAGE=docker.onedata.org/oneclient:ID-6a63d5d206

# And just run
./run.sh
~~~