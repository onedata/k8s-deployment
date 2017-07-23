# K8s Deployment with Helm
This repository serves as an entry point for Onedata continuous deployment pipeline. It's meant to be used by automatic task runners of continuous integration systems as well as individual developers in their daily routine.

## Repository structure
### run.sh
Used for deploying particular configuration of a chosen helm chart in a given namespace on a Kubernetes cluster. Please refer to `run.sh -h` for a detailed documentation.

### landscapes

> Note: originally I planned to use [landscaper](https://github.com/Eneco/landscaper), but at the time of development it lacked compatibility with the newest helm version. Hence the name. Instead, the *landscape* is realised just by invoking `helm install -f <config file>...`.

A landscape is a named set of files
- `landscape.yaml` containing configuration for a helm chart
- `deploy.sh` a script that contains the deployment procedure for a chart, specifying its **repository**, **name**, and **version**.
- `tmuxp.yaml` an optional [tmuxp](https://github.com/tony/tmuxp/) configuration used to easily connect a deployed helm release. Includes integration with [iTerm](https://www.iterm2.com/).

### docker

Docker composes with an entry-point which realises a deployment using a container that includes needed versions of *git*, *kubectl*, *helm* etc.

## Example workflows

### Onedata developer

Typically developer wants to deploy a release with customized docker images, the example command that realizes it (uses a convenient flag `--prefix`) using a *develop* landscape:
~~~bash
 ./run.sh --debug --landscape develop --ns develop --rn develop --tmuxp  --prefix docker.onedata.org/ --op oneprovider:ID-795e3f2827 --oc oneclient:ID-f5cd39a89c --oz onezone:ID-df63ec7ae2 --cli rest-cli:ID-07f1c50d9e
~~~

On rare occasion, developer might want to customise the release even further. To do that please copy the *landscapes/develop* landscape directory to *landscapes/random_custom_name*. In the copied directory modify the *landscape.yaml* file to customise the deployment process. Next run the same command as above, but replace ` --landscape develop` with ` --landscape random_custom_name`. 

### Chart developer

By default, the charts are downloaded from the Onedata chart repository located at [onedata/charts](https://github.com/onedata/charts) on a `gh-pages` branch. In order to modify and test new charts, in the same way, they will be used by the users or automated tasks, one needs:

- to clone the *onedata/charts* repository and use the `--helm-local-charts-dir <path to cloned chart repo>` flag to allow helm in *docker-compose* to discover local charts,
- change the chart name in `deploy.sh`, from eg. *onedata/onedata-3p* to *onedata-3*, that way to deployment will use a *local/onedata-3p* chart instead of downloading it from the *onedata/charts* repo.

### Automated deployments

Virtually the same use case as in *Onedata developer*, Tthe only extra requirement is the `kubectl` configuration which custom location can be passed with `--kube-config` flag.

Example command used by our continuous deployment task:
~~~bash
run.sh --kube-config "$KUBE_CONFIG" --ns "$NAMESPACE" --rn "$RELEASE_NAME" --op "$OP_IMAGE" --oc "$OC_IMAGE" --oz "$OZ_IMAGE" --cli "$CLI_IMAGE" --landscape develop --debug
~~~

## Attaching to a deployed release
For the sake of automation of performing common tasks on a complex deployment we use [tmux](https://github.com/tmux/tmux/wiki), [tmuxp](https://github.com/tony/tmuxp/) with optional [iTerm](https://www.iterm2.com/) integration support.

### `--tmuxp` flag
When running `run.sh` you can supply a `--tmuxp` flag that will, in turn, generate a file with a name:

~~~bash
tmuxp.<landscape>.<namespace>.<release name>.<flags>.sh
~~~
you can use this script to attach to a deployed release. The script sources a file `utils/run_tmuxp.sh` and must be placed in the root fo this repository.

By default the name includes all possible flags `cidk`, where:

- **c** stands for configuring kubectl **context** by creating a context corresponding to a release parameters and setting this context as default.
- **k** stands for, if the tmux session exists with the conflicting name, **kill** it
- **d** add **detach** flag to *tmuxp* command, prevents automatic attach to tmux
- **i** stands for, attach to the tmux session using iTerm integration.

### onedata-envat

Similarly to the method above, this script allows you to attach to a deployed release using tmux. This time, the release parameters can be supplied as flags and the script can be used either from the root of this repository or by placing symbolic link to in somewhere in your `$PATH`. See `-h` for a more detailed description of possible flags.
