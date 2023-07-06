#!/bin/bash
# Install and configure JupyterLab S3 Browser extension for SageMaker Studio JLv1 or v3.

set -eu

# Since pip can sometimes fail to take all installed packages into account, we'll look up and
# specify some important package versions to avoid pip breaking things:
BOTO3_VER=`pip show boto3 | grep 'Version:' | sed 's/Version: //'`
BOTOCORE_VER=`pip show botocore | grep 'Version:' | sed 's/Version: //'`
JUPYTER_SERVER_VER=`pip show jupyter-server | grep 'Version:' | sed 's/Version: //'`
JUPYTERLAB_SERVER_VER=`pip show jupyterlab-server | grep 'Version:' | sed 's/Version: //'`

echo "JupyterServer $JUPYTER_SERVER_VER, JupyterLab $JUPYTERLAB_SERVER_VER"

export AWS_SAGEMAKER_JUPYTERSERVER_IMAGE="${AWS_SAGEMAKER_JUPYTERSERVER_IMAGE:-'jupyter-server'}"
if [ "$AWS_SAGEMAKER_JUPYTERSERVER_IMAGE" = "jupyter-server-3" ] ; then
    echo "Installing S3 browser for JupyterLab v3"

    # Activate the conda environment where Jupyter is installed:
    eval "$(conda shell.bash hook)"
    conda activate studio
    
    pip install jupyterlab-s3-browser \
        boto3=$BOTO3_VER \
        botocore=$BOTOCORE_VER \
        jupyter-server==$JUPYTER_SERVER_VER \
        jupyterlab-server==$JUPYTERLAB_SERVER_VER
    
    conda deactivate
else
    echo "Installing S3 browser for JupyterLab v1"
    # Straight `jupyter labextension install jupyterlab-s3-browser` will time out
    #jupyter labextension install jupyterlab-s3-browser
    #pip install jupyterlab-s3-browser #\
        #boto3==$BOTO3_VER \
        #botocore==$BOTOCORE_VER
    #jlpm config set cache-folder /tmp/yarncache
    #jupyter lab build --debug --minimize=False
    #jupyter serverextension enable --py jupyterlab_s3_browser
    source activate base
    jlpm config set cache-folder /tmp/yarncache
    jupyter labextension install jupyterlab-s3-browser --debug --minimize=False
    #pip install "jupyterlab-s3-browser<0.9" #\
        # jupyter-server==$JUPYTER_SERVER_VER \
        # jupyterlab-server==$JUPYTERLAB_SERVER_VER
    source deactivate
    # --no-build
    #jupyter lab build --debug --minimize=False

    # TODO: Why is this still broken???
fi

# Once components are installed and configured, restart Jupyter to make sure everything propagates:
echo "Restarting Jupyter server..."
nohup supervisorctl -c /etc/supervisor/conf.d/supervisord.conf restart jupyterlabserver \
    > /dev/null 2>&1
