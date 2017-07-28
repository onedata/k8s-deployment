#!/usr/bin/env bash

command_exists() {
  command -v "$@" > /dev/null 2>&1
}

check_requirement() {
  if ! command_exists "$@" ; then
    echo "Cannot find command: $*"
    echo "Please install it and rerun the script."
    return 1
  fi   
}

check_requirements() {
  for requirement in "$@" ; do
    check_requirement "$requirement" || exit 1
  done
}

usage() {
cat <<EOF
This script deploys a landscape and allows for overriding docker images: 

${0##*/} [--debug] [--dry-run] [--kube-cofig <path>] [--helm-local-dir <path>] [--helm-local-charts-dir <path>] [--tmuxp ] [--rn <release name>] [--ns <namespace>] [ --prefix <prefix>]
         [--landscape <name>] [--oz <onezone image> ] [--op <oneprovider image> ] [--oc <oneclient image> ] [--cli <rest cli image>]

Options:
  -h, --help                 display this help and exit
  --debug                    pass --dry-debug flag to helm
  --dry-run                  pass --dry-run flag to helm
  --kube-config              path you for kubectl config file, defaults to ~/.kube/config
  --tmuxp                    generate tmuxp configuration to access the deployment
  --helm-local-charts-dir    path a directory with you local onedata charts
  --helm-local-dir           path you for helm config directory, defaults to ~/.helm
  --landscape                name of a directory in landscapes directory you want to use, defaults to develop
  --lifetime                 number or hours ([1-9][0-9]*), after which this deployment will be scheduled for deletion
  --user                     set owner of this release (defaults to $USER)
  --rn                       helm release name 
  --ns                       namespace to deploy into
  --prefix                   prefix to be prepended to all overridden images
  --oz                       onezone docker image
  --op                       oneprovider docker image
  --oc                       oneclient docker image
  --cli                      rest-cli docker image

Example:
Can be run without any arguments, then all needed values are taken from your ~/.kube/config:
${0##*/} ./run.sh
${0##*/} ./run.sh --kube-config /not/standard/path/to/config

You can choose to override only one image:
${0##*/} ./run.sh --op oneprovider:id-a551c1c054

If all overriden images are from the same repo, use prefix to make your life easier:
${0##*/} ./run.sh  --dry-run --debug --ns develop --rn develop  --prefix docker.onedata.org/ --op oneprovider:id-a551c1c054 --oc oneclient:id-6a63d5d206 --oz onezone:ID-b5ea2dcf0a --cli rest-cli:ID-79deed39f3

For a chart developer to deploy edited charts from your local machine with custom landscape:
./run.sh  --ns dev --rn dev --debug --helm-local-charts-dir ~/onedata-charts --landscape develop

EOF
exit 1
}

main() {

  if (( ! $# )); then
    usage
  fi

  check_requirements docker docker-compose curl jq tmux tmuxp

  kube_config=""
  namespace=""
  release_name=""
  oz_image=""
  op_image=""
  oc_image=""
  cli_image=""
  helm_debug=""
  helm_dry_run=""
  generate_tmuxp=0
  helm_local_dir=""
  helm_local_charts_dir=""
  landscape=develop
  lifetime=12
  lifetime_set=false
  user=$USER

  while (( $# )); do
      case $1 in
          -h|-\?|--help)   # Call a "usage" function to display a synopsis, then exit.
              usage
              exit 0
              ;;
          --oz)
              oz_image=$2
              shift
              ;;
          --op)
              op_image=$2
              shift
              ;;
          --oc)
              oc_image=$2
              shift
              ;;
          --cli)
              cli_image=$2
              shift
              ;;
          --prefix)
              image_prefix=$2
              shift
              ;;            
          --kube-config)
              kube_config=$2
              shift
              ;;
          --ns)
              namespace=$2
              shift
              ;;
          --rn)
              release_name=$2
              shift
              ;;
          --debug)
              helm_debug=true
              ;;
          --dry-run)
              helm_dry_run=true
              ;;
          --tmuxp)
              generate_tmuxp=1
              ;;
          --helm-local-dir)
              helm_local_dir=$2
              shift
              ;;
          --helm-local-charts-dir)
              helm_local_charts_dir=$2
              shift
              ;;
          --helm-local-charts-dir)
              helm_local_charts_dir=$2
              shift
              ;;
          --landscape)
              landscape=$2
              shift
              ;;
          --lifetime)
              lifetime=$2
              lifetime_set=true
              shift
              ;;
          --user)
              user=$2
              shift
              ;;
          --debug)
              ;;
          -?*)
              printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
              exit 1
              ;;
          *)
              die "no option $1"
              ;;
      esac
      shift
  done

    if [[ -z $kube_config ]] ; then kube_config="~/.kube/config" ; fi
    if [[ -z $helm_local_dir ]] ; then helm_local_dir="~/.helm" ; fi
    
    export kube_config="$kube_config"
    export namespace=$namespace
    export release_name=$release_name
    export oz_image=${image_prefix}$oz_image
    export op_image=${image_prefix}$op_image
    export oc_image=${image_prefix}$oc_image
    export cli_image=${image_prefix}$cli_image
    export helm_debug=$helm_debug
    export helm_dry_run=$helm_dry_run
    export helm_local_dir=$helm_local_dir
    export helm_local_charts_dir=$helm_local_charts_dir
    export landscape=$landscape
    export user=$user
    export lifetime=$lifetime

    type docker-compose >/dev/null 2>&1 || {
        echo >&2 "I require docker-compose but it's not installed. Downloading..." ;
        curl -L https://github.com/docker/compose/releases/download/1.13.0/docker-compose-`uname -s`-`uname -m` > docker-compose
        chmod +x docker-compose
        export PATH=$PATH:.
    }

    docker_compose_dir="docker/run/"
    local_copy_of_docker_compose_yaml=$(cat $docker_compose_dir/docker-compose.yaml)
    if [[ $helm_local_charts_dir != "" ]]; then
        local_copy_of_docker_compose_yaml=$(echo "$local_copy_of_docker_compose_yaml" | sed  -e 's#volumes:#volumes:\n      - ${helm_local_dir}:/root/.helm_ro:ro#g')
        local_copy_of_docker_compose_yaml=$(echo "$local_copy_of_docker_compose_yaml" | sed  -e 's#volumes:#volumes:\n      - ${helm_local_charts_dir}:/root/charts:ro#g')
    fi 

    docker-compose -f <(echo "$local_copy_of_docker_compose_yaml") --project-directory "$docker_compose_dir" config
    docker-compose -f <(echo "$local_copy_of_docker_compose_yaml") --project-directory "$docker_compose_dir" up --force-recreate

    container_id=$(docker-compose -f <(echo "$local_copy_of_docker_compose_yaml")  --project-directory "$docker_compose_dir" ps -q 2>/dev/null)
    container_envs=$(docker inspect $container_id | jq -r '.[0].Config.Env[]')
    namespace=$(echo "$container_envs" | grep namespace)
    namespace=${namespace#*=}
    release_name=$(echo "$container_envs" | grep release_name)
    release_name=${release_name#*=}

    docker-compose -f <(echo "$local_copy_of_docker_compose_yaml") --project-directory "$docker_compose_dir" rm  -v -s -f

    if (( $generate_tmuxp )) ; then
    tmuxp_name="tmuxp.${landscape}.${namespace}.${release_name}.cidk.sh"
cat <<EOF >$tmuxp_name
source utils/run_tmuxp.sh
main
EOF
    chmod +x "$tmuxp_name"
    fi

    if [[ -f docker-compose ]]; then
        rm docker-compose
    fi

    if $lifetime_set ; then
      echo ""
      echo "INFO: Your deployment will be scheduled for automatic deletion within $lifetime hours!"  
    else
      echo ""
      echo "" && echo "WARNING: You did not specify --lifetime, your deployment will be scheduled for automatic deletion within 12 hours!"
    fi
}

main "$@"