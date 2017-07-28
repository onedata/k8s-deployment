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

${0##*/} [--dry-run] [--kube-cofig <path>]

Options:
  -h, --help                 display this help and exit
  --dry-run                  display what would be deleted, but do not delete anything
  --kube-config              path you for kubectl config file, defaults to ~/.kube/config


Example:
Can be run without any arguments, then all needed values are taken from your ~/.kube/config:
${0##*/}
${0##*/} --kube-config /not/standard/path/to/config

EOF
exit 1
}

main() {

  check_requirements docker docker-compose curl

  kube_config=""
  dry_run=false
  
  while (( $# )); do
      case $1 in
          -h|-\?|--help)   # Call a "usage" function to display a synopsis, then exit.
              usage
              exit 0
              ;;
          --kube-config)
              kube_config=$2
              shift
              ;;
          --dry-run)
              dry_run=true
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
    
    export kube_config="$kube_config"
    export dry_run=$dry_run

    type docker-compose >/dev/null 2>&1 || {
        echo >&2 "I require docker-compose but it's not installed. Downloading..." ;
        curl -L https://github.com/docker/compose/releases/download/1.13.0/docker-compose-`uname -s`-`uname -m` > docker-compose
        chmod +x docker-compose
        export PATH=$PATH:.
    }

    docker_compose_dir="docker/clean/"
    local_copy_of_docker_compose_yaml=$(cat $docker_compose_dir/docker-compose.yaml)

    docker-compose -f <(echo "$local_copy_of_docker_compose_yaml") --project-directory "$docker_compose_dir" config
    docker-compose -f <(echo "$local_copy_of_docker_compose_yaml") --project-directory "$docker_compose_dir" up --force-recreate
    docker-compose -f <(echo "$local_copy_of_docker_compose_yaml") --project-directory "$docker_compose_dir" rm  -v -s -f

    if [[ -f docker-compose ]]; then
        rm docker-compose
    fi
}

main "$@"