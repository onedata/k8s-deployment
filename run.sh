#!/usr/bin/env bash

BAMBOO_URL="https://bamboo.onedata.org"
BABBOO_CACHE_FILE="bamboo_images_cache"
BAMBOO_CREDENTIALS_FILE="bamboo"

aliases() {
  case $( uname -s ) in
    Linux)
          _sed=sed
          ;;
    Darwin)
          _sed=gsed
          ;;
  esac
}
aliases

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

authenticate_with_bamboo() {
  [ -f "$BAMBOO_CREDENTIALS_FILE" ] && source "$BAMBOO_CREDENTIALS_FILE"  
  if [[ -z ${PL_USER+x} ]] ; then 
    echo "WARNINING: $BAMBOO_CREDENTIALS_FILE does not contain export of PL_USER, falling back to tty:"
    printf "Please provider your bamboo username: "
    read -r PL_USER </dev/tty
  fi
  [[ -z ${PL_USER+x} ]] && echo "ERROR: please export PL_USER variable. Exiting." && exit 1 ;
  echo "Authenticating with bamboo using user PL_USER=$PL_USER"
  if [[ -z ${PL_PASSWORD+x} ]] ; then 
    echo "WARNINING: $BAMBOO_CREDENTIALS_FILE does not contain export of PL_PASSWORD, falling back to tty:"
    printf "Please provider your bamboo password: "
    unset PL_PASSWORD
    while IFS= read -p "$prompt" -r -s -n 1 _pl_passowrd_char
    do
        if [[ ${_pl_passowrd_char} == $'\0' ]]
        then
            break
        fi
        prompt='*'
        PL_PASSWORD+="$_pl_passowrd_char"
    done
  fi
  [[ -z ${PL_PASSWORD+x} ]] && echo "ERROR: please export PL_PASSWORD variable. Exiting." && exit 1 ;
  curl -vv --silent -u "$PL_USER:$PL_PASSWORD" --cookie-jar bamboo_cookie.txt "${BAMBOO_URL}/userlogin!default.action?os_authType=basic" --head
}

download_artefact() {
  local build_number="$1"
  local branch_number="$2"
  local artefact=""

  touch $BABBOO_CACHE_FILE ;
  if [[ -n ${bamboo_cache+x} ]] ; then
    # Substitute a lack of branch_number with 0, so cache does not have an empty column
    [[ "$branch_number" = "" ]] && branch_number=0
    read cbranch_number cbuild_number cbamboo_oz_image cbamboo_op_image cbamboo_oc_image cbamboo_odfsj_image cbamboo_cli_image cbamboo_luma_image < <(grep "^$branch_number $build_number" ./bamboo_images_cache)
    if [[ "$cbamboo_oz_image" != "" ]] && [[ "$cbamboo_op_image" != "" ]] && [[ "$cbamboo_oc_image" != "" ]] && [[ "$cbamboo_odfsj_image" != "" ]] && [[ "$cbamboo_cli_image" != "" ]] && [[ "$cbamboo_luma_image" != "" ]] ; then
      export bamboo_oz_image=$cbamboo_oz_image
      export bamboo_op_image=$cbamboo_op_image
      export bamboo_oc_image=$cbamboo_oc_image
      export bamboo_odfsj_image=$cbamboo_odfsj_image
      export bamboo_cli_image=$cbamboo_cli_image
      export bamboo_luma_image=$cbamboo_luma_image
      # Substitute a branch_number number 0 back, to display lack of branch number for default bamboo branch
      [[ "$branch_number" = 0 ]] && branch_number=""
      echo "Found images for build_number=$build_number and branch_number=$branch_number in cache."
      return
    else
      echo "Failed to find images for build_number=$build_number and branch_number=$branch_number"
    fi
  fi
  echo "Downloading build ${BAMBOO_URL}/browse/ODSRV-K8SD${branch_number}-${build_number}"

  i=0;
  # Substitute a branch_number number 0 back, to be used when querring bamboo
  [[ "$branch_number" = "0" ]] && branch_number=""
  authenticate_with_bamboo
  while : ; do
    artefact="$(curl --silent --cookie bamboo_cookie.txt ${BAMBOO_URL}/browse/ODSRV-K8SD${branch_number}-${build_number}/artifact/shared/onedata-docker-build-list.txt/onedata-docker-build-list.txt)"
    if [[ "$artefact" == "" ]] ; then
      ((i++))
      if [[ $i -le 3 ]] ; then
          echo "Faild to download artefact (${i} try out of 3). Probably bamboo sesion expired. Renewing session..."
          authenticate_with_bamboo
        else
          echo "After $i attemtps failed to download artefact. Exiting..." ;
          exit 1
      fi
    else
      while read line; do
        component=`echo ${line} | cut -d : -f 1`
        image=`echo ${line} | cut -d : -f 2-`
        [[ $component =~ onezone ]] && export bamboo_oz_image=$image
        [[ $component =~ oneprovider ]] && export bamboo_op_image=$image
        [[ $component =~ oneclient ]]  && export bamboo_oc_image=$image
        [[ $component =~ onedatafs-jupyter ]]  && export bamboo_odfsj_image=$image
        [[ $component =~ rest\-cli ]] && export bamboo_cli_image=$image
        [[ $component =~ luma ]] && export bamboo_luma_image=$image
      done < <(echo "$artefact")
      break
    fi
  done
  if [[ "$bamboo_oz_image" != "" ]] && [[ "$bamboo_op_image" != "" ]] && [[ "$bamboo_oc_image" != "" ]] && [[ "$bamboo_odfsj_image" != "" ]] && [[ "$bamboo_cli_image" != "" ]] && [[ "$bamboo_luma_image" != "" ]] ; then
      echo "Saving downloaded build images into ./bamboo_images_cache"
      # Substitute a lack of branch_number with 0, so cache does not have an empty column
      [[ "$branch_number" = "" ]] && branch_number=0
      cat <(echo "$branch_number $build_number $bamboo_oz_image $bamboo_op_image $bamboo_oc_image $bamboo_odfsj_image $bamboo_cli_image $bamboo_luma_image") <(grep -v "^488 24" bamboo_images_cache) | sponge $BABBOO_CACHE_FILE;
  fi
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
  --bamboo-build             a build number of k8s-deployment build plan https://bamboo.plgrid.pl/browse/ODSRV-K8SD-<build>
  --bamboo-branch            a branch number of k8s-deployment build plan https://bamboo.plgrid.pl/browse/ODSRV-K8SD<branch>
  --bamboo-cache             search a cache file for builds before connecting to bamboo server
  --user                     set owner of this release (defaults to $USER)
  --rn                       helm release name 
  --ns                       namespace to deploy into
  --prefix                   prefix to be prepended to all overridden images
  --oz                       onezone docker image
  --op                       oneprovider docker image
  --oc                       oneclient docker image
  --odfsj                     onedatafs jupyter docker image
  --lu                       luma docker image
  --cli                      rest-cli docker image
  --wait-for-clean-namespace wait for all pods to exit before starting a deployment

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
  odfsj_image=""
  cli_image=""
  luma_image=""
  helm_debug=""
  helm_dry_run=""
  bamboo_build=""
  bamboo_branch=""
  generate_tmuxp=0
  helm_local_dir=""
  helm_local_charts_dir=""
  landscape=develop
  lifetime=12
  lifetime_set=false
  user=$USER
  wait_for_clean_namespace=0

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
          --odfsj)
              odfsj_image=$2
              shift
              ;;
          --cli)
              cli_image=$2
              shift
              ;;
          --lu)
              luma_image=$2
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
          --bamboo-build)
              bamboo_build=$2
              shift
              ;;
          --bamboo-branch)
              bamboo_branch=$2
              shift
              ;;
          --bamboo-cache)
              bamboo_cache=true
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
          --wait-for-clean-namespace)
              wait_for_clean_namespace=1
              shift
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
    
    [[ "$bamboo_build" != "" ]] && download_artefact "$bamboo_build" "$bamboo_branch"

    if [[ "$oz_image" != "" ]]; then oz_image=${image_prefix}$oz_image  ; else oz_image="$bamboo_oz_image" ; fi
    if [[ "$op_image" != "" ]]; then op_image=${image_prefix}$op_image ; else op_image="$bamboo_op_image" ; fi
    if [[ "$oc_image" != "" ]]; then oc_image=${image_prefix}$oc_image ; else oc_image="$bamboo_oc_image" ; fi
    if [[ "$odfsj_image" != "" ]]; then odfsj_image=${image_prefix}$odfsj_image ; else odfsj_image="$bamboo_odfsj_image" ; fi
    if [[ "$cli_image" != "" ]]; then cli_image=${image_prefix}$cli_image ; else cli_image="$bamboo_cli_image" ; fi
    if [[ "$luma_image" != "" ]]; then luma_image=${image_prefix}$luma_image ; else luma_image="$bamboo_luma_image" ; fi

    default_image=0
    [[ "$oz_image" = "" ]] && echo "Error: Missing Onezone image! The default image will be used!" && default_image=1
    [[ "$op_image" = "" ]] && echo "Error: Missing Oneprovider image! The default image will be used!" && default_image=1
    [[ "$oc_image" = "" ]] && echo "Error: Missing Oneclient image! The default image will be used!" && default_image=1
    [[ "$odfsj_image" = "" ]] && echo "Error: Missing OnedataFS Jupyter image! The default image will be used!" && default_image=1
    [[ "$cli_image" = "" ]] && echo "Error: Missing Onedata-cli image! The default image will be used!" && default_image=1
    [[ "$luma_image" = "" ]] && echo "Error: Missing Luma image! The default image will be used!" && default_image=1
    
    if [[ "$default_image" = "1" ]] ; then
        read -p "Do you reall want to use default image values? " default_image_yn
        case $default_image_yn in
            [Yy]* ) ;;
            [Nn]* ) exit ;;
            * ) echo "Please answer yes(y) or no(n)." ;;
        esac
    fi

    export kube_config="$kube_config"
    export namespace=$namespace
    export release_name="$release_name"
    export oz_image
    export op_image
    export oc_image
    export odfsj_image
    export cli_image
    export luma_image
    export helm_debug=$helm_debug
    export helm_dry_run=$helm_dry_run
    export helm_local_dir=$helm_local_dir
    export helm_local_charts_dir=$helm_local_charts_dir
    export landscape=$landscape
    export user=$user
    export lifetime=$lifetime
    export wait_for_clean_namespace

    type docker-compose >/dev/null 2>&1 || {
        echo >&2 "I require docker-compose but it's not installed. Downloading..." ;
        curl -L https://github.com/docker/compose/releases/download/1.23.2/docker-compose-`uname -s`-`uname -m` > docker-compose
        chmod +x docker-compose
        export PATH=$PATH:.
    }

    docker_compose_dir="docker/run/"
    local_copy_of_docker_compose_yaml=$(cat $docker_compose_dir/docker-compose.yaml)
    if [[ $helm_local_charts_dir != "" ]]; then
        local_copy_of_docker_compose_yaml=$(echo "$local_copy_of_docker_compose_yaml" | $_sed  -e 's#volumes:#volumes:\n      - ${helm_local_dir}:/root/.helm_ro:ro#g')
        local_copy_of_docker_compose_yaml=$(echo "$local_copy_of_docker_compose_yaml" | $_sed  -e 's#volumes:#volumes:\n      - ${helm_local_charts_dir}:/root/charts:ro#g')
    fi 
    echo "b"
    echo "$local_copy_of_docker_compose_yaml"
    docker-compose -f <(echo "$local_copy_of_docker_compose_yaml") --project-directory "$docker_compose_dir" config
    docker-compose -f <(echo "$local_copy_of_docker_compose_yaml") --project-directory "$docker_compose_dir" up --force-recreate
    echo "a"

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