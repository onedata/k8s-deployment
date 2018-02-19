#/usr/bin/env bash

main() {
    calling_script_name=${0##*/}
    calling_script_name=${calling_script_name%.sh}
    

    IFS='.' read tmuxp landscape namespace release_name flags <<<"$calling_script_name"

    # c stands for configure context
    if [[ $flags =~ c ]]; then
        kubectl config set-context $(kubectl config current-context) --namespace=${namespace}
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
        detach="-d"
    fi

    tmuxp load landscapes/$landscape/tmuxp.yaml $detach

    # i stands for launch iterm integration
    if [[ $flags =~ i ]]; then
        tmux -CC at -t "$session_name"
    fi
    
}

