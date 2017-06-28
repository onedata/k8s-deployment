#/usr/bin/env bash

main() {
    calling_script_name=${0##*/}
    calling_script_name=${calling_script_name%.sh}
    

    read context_name cluster_name kube_user namespace <<< $(kubectl config get-contexts | grep "*" | tr -s ' ' | cut -d ' ' -f 2-)
    IFS='.' read tmuxp landscape namespace release_name flags <<<"$calling_script_name"

    echo "$flags"
    # c stands for configure context
    if [[ $flags =~ c ]]; then
        echo "echo c"
        kubectl config set-context ${cluster_name}-${kube_user}-${namespace} --cluster=${cluster_name} --namespace=${namespace} --user=${kube_user}
        kubectl config use-context ${cluster_name}-${kube_user}-${namespace}
    fi


    export release_name=$release_name
    export kube_user
    export landscape
    export namespace
    export release_name

    # k stands for kill the session if it existed        
    if [[ $flags =~ k ]]; then
        echo "l"
        if tmux has-session $session_name ; then
            tmux kill-session $session_name
        fi
    fi

    # d stands for detach
    detach=""
    if [[ $flags =~ d ]]; then
        echo "D"
        detach="-d"
    fi

    tmuxp load landscapes/$landscape/tmuxp.yaml $detach

    # i stands for launch iterm integration
    if [[ $flags =~ i ]]; then
        tmux -CC at -t "$session_name"
    fi
    
}

