#!/bin/bash
# Snippets to check and condition on the active JupyterLab version in SMStudio
# Different JLab versions support different extensions, and past SMStudio environments have
# differed slightly in conda setup between the major JLab versions.

####  One option is to check the SMStudio image name:
export AWS_SAGEMAKER_JUPYTERSERVER_IMAGE="${AWS_SAGEMAKER_JUPYTERSERVER_IMAGE:-'jupyter-server'}"
# ...Or could alternatively if conda info --envs | grep ^studio; then
if [ "$AWS_SAGEMAKER_JUPYTERSERVER_IMAGE" = "jupyter-server-3" ] ; then
    # In JLv3, you want the 'studio' conda env for installing JupyterServer extensions:
    eval "$(conda shell.bash hook)"
    conda activate studio
else
    # In JLv1, Studio used the 'base' conda env for installing JupyterServer extensions:
    source activate base
fi;

####  For a more granular picture, you may want full semantic version comparison:
# Configure the min required version first
MIN_JLAB_VERSION='3.1.0'

# Function to compare two X.Y.Z semantic version strings
# Returns 0 if equal, 1 if A > B, 2 if A < B.
# From https://stackoverflow.com/a/4025065
# (Since this fn returns non-zero codes, must run it in +e mode)
compare_semvers () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

# Check the JL version and branch based on the comparison:
JLAB_VERSION=`jupyter lab --version`
echo "Found JupyterLab version $JLAB_VERSION"
set +e
compare_semvers $MIN_JLAB_VERSION $JLAB_VERSION
VERCOMP_RESULT=$?
set -e

if [ $VERCOMP_RESULT -eq 1 ]; then
    echo "JupyterLab version '$JLAB_VERSION' is less than '$MIN_JLAB_VERSION'"
    # Maybe `exit 0` here if you want to skip installs/etc?
fi


#### (Whatever your script actually wants to do probably goes here)


#### At the end of your script, assuming you customized Jupyter:
echo "Restarting Jupyter server..."
if [ "$AWS_SAGEMAKER_JUPYTERSERVER_IMAGE" = "jupyter-server-3" ] ; then
    # In JLv3, Studio has a nice CLI utility for restarting the server:
    restart-jupyter-server
else
    # But the following should work fine in either v1 or v3:
    nohup supervisorctl -c /etc/supervisor/conf.d/supervisord.conf restart jupyterlabserver \
        > /dev/null 2>&1
fi;
