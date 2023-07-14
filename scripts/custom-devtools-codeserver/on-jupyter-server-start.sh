#!/bin/bash
# Configure (VS) Code Server alongside JupyterLab IDE tools on SMStudio (for JupyterLab v3 only)
#
# This script sets up:
# - Code Server (as in VSCode) and launcher extension
# - Amazon CodeWhisperer
# - JupyterLab S3 browser extension
# - Code completion, continuous hinting, hover tips, code formatting, and markdown spell-checking
#   via jupyterlab-lsp
# - ipycanvas - A library for drawing interactive canvases in notebooks
#
# TODO: jupyterlab-unfold, jupyterlab-skip-traceback
# TODO: MAYBE: jupyterlab-execute-time, stickyland
#
# Inspired by:
# https://github.com/aws-samples/amazon-sagemaker-codeserver/blob/main/install-scripts/studio/install-codeserver.sh

set -eu

####  CONFIGURATION
CODE_SERVER_VERSION="4.14.1"
CODE_SERVER_INSTALL_LOC="/opt/.cs"
XDG_DATA_HOME="/opt/.xdg/data"
XDG_CONFIG_HOME="/opt/.xdg/config"
INSTALL_PYTHON_EXTENSION=1
CREATE_NEW_CONDA_ENV=1
CONDA_ENV_LOCATION='/opt/.cs/conda/envs/codeserver_py39'
CONDA_ENV_PYTHON_VERSION="3.9"
USE_CUSTOM_EXTENSION_GALLERY=0
EXTENSION_GALLERY_CONFIG='{{\"serviceUrl\":\"\",\"cacheUrl\":\"\",\"itemUrl\":\"\",\"controlUrl\":\"\",\"recommendationsUrl\":\"\"}}'
LAUNCHER_ENTRY_TITLE='Code Server'
PROXY_PATH='codeserver'
LAB_3_EXTENSION_DOWNLOAD_URL='https://github.com/aws-samples/amazon-sagemaker-codeserver/releases/download/v0.1.5/sagemaker-jproxy-launcher-ext-0.1.3.tar.gz'


export AWS_SAGEMAKER_JUPYTERSERVER_IMAGE="${AWS_SAGEMAKER_JUPYTERSERVER_IMAGE:-'jupyter-server'}"
if [ "$AWS_SAGEMAKER_JUPYTERSERVER_IMAGE" != "jupyter-server-3" ] ; then
    echo "SageMaker version '$AWS_SAGEMAKER_JUPYTERSERVER_IMAGE' does not match 'jupyter-server-3'"
    echo "Skipping assistive features install (which depends on JupyterLab v3)"
    exit 0
fi

# Activate the conda environment where Jupyter is installed:
eval "$(conda shell.bash hook)"
conda activate studio

# Find installed versions of important packages so we can pin them to prevent pip overriding:
BOTO3_VER=`pip show boto3 | grep 'Version:' | sed 's/Version: //'`
BOTOCORE_VER=`pip show botocore | grep 'Version:' | sed 's/Version: //'`
JUPYTER_SERVER_VER=`pip show jupyter-server | grep 'Version:' | sed 's/Version: //'`
JUPYTERLAB_SERVER_VER=`pip show jupyterlab-server | grep 'Version:' | sed 's/Version: //'`

# For Code Server:
sudo mkdir -p /opt/.cs
sudo mkdir -p /opt/.xdg
sudo chown sagemaker-user /opt/.cs
sudo chown sagemaker-user /opt/.xdg
export XDG_DATA_HOME=$XDG_DATA_HOME
export XDG_CONFIG_HOME=$XDG_CONFIG_HOME
export PATH="$CODE_SERVER_INSTALL_LOC/bin/:$PATH"

# Install code-server standalone:
mkdir -p ${CODE_SERVER_INSTALL_LOC}/lib ${CODE_SERVER_INSTALL_LOC}/bin
curl -fL https://github.com/coder/code-server/releases/download/v$CODE_SERVER_VERSION/code-server-$CODE_SERVER_VERSION-linux-amd64.tar.gz \
| tar -C ${CODE_SERVER_INSTALL_LOC}/lib -xz
rm -rf ${CODE_SERVER_INSTALL_LOC}/lib/code-server-$CODE_SERVER_VERSION
mv ${CODE_SERVER_INSTALL_LOC}/lib/code-server-$CODE_SERVER_VERSION-linux-amd64 ${CODE_SERVER_INSTALL_LOC}/lib/code-server-$CODE_SERVER_VERSION
ln -sf ${CODE_SERVER_INSTALL_LOC}/lib/code-server-$CODE_SERVER_VERSION/bin/code-server ${CODE_SERVER_INSTALL_LOC}/bin/code-server

# Create new conda env for Code Server
if [ $CREATE_NEW_CONDA_ENV -eq 1 ]
then
    conda create --prefix $CONDA_ENV_LOCATION python=$CONDA_ENV_PYTHON_VERSION -y
    conda config --add envs_dirs "${CONDA_ENV_LOCATION%/*}"
fi

# Install ms-python extension for Code Server
if [ $USE_CUSTOM_EXTENSION_GALLERY -eq 0 -a $INSTALL_PYTHON_EXTENSION -eq 1 ]
then
    code-server --install-extension ms-python.python --force

    # if the new conda env was created, add configuration to set as default
    if [ $CREATE_NEW_CONDA_ENV -eq 1 ]
    then
        CODE_SERVER_MACHINE_SETTINGS_FILE="$XDG_DATA_HOME/code-server/Machine/settings.json"
        if grep -q "python.defaultInterpreterPath" "$CODE_SERVER_MACHINE_SETTINGS_FILE"
        then
            echo "Default interepreter path is already set."
        else
            cat >>$CODE_SERVER_MACHINE_SETTINGS_FILE <<- MACHINESETTINGS
{
    "python.defaultInterpreterPath": "$CONDA_ENV_LOCATION/bin"
}
MACHINESETTINGS
        fi
    fi
fi

# Use custom extension gallery for Code Server
EXT_GALLERY_JSON=''
if [ $USE_CUSTOM_EXTENSION_GALLERY -eq 1 ]
then
    EXT_GALLERY_JSON="'EXTENSIONS_GALLERY': '$EXTENSION_GALLERY_CONFIG'"
fi

# Configure proxy settings and launcher for Code Server:
JUPYTER_CONFIG_FILE="/home/sagemaker-user/.jupyter/jupyter_notebook_config.py"
if grep -q "$CODE_SERVER_INSTALL_LOC/bin" "$JUPYTER_CONFIG_FILE"
then
    echo "Server-proxy configuration already set in Jupyter notebook config."
else
    mkdir -p /home/sagemaker-user/.jupyter
    cat >>/home/sagemaker-user/.jupyter/jupyter_notebook_config.py <<- NBCONFIG
c.ServerProxy.servers = {
    '$PROXY_PATH': {
        'launcher_entry': {
                'enabled': True,
                'title': '$LAUNCHER_ENTRY_TITLE',
                'icon_path': 'codeserver.svg'
        },
        'command': ['$CODE_SERVER_INSTALL_LOC/bin/code-server', '--auth', 'none', '--disable-telemetry', '--bind-addr', '127.0.0.1:{port}'],
        'environment' : {
                            'XDG_DATA_HOME' : '$XDG_DATA_HOME', 
                            'XDG_CONFIG_HOME': '$XDG_CONFIG_HOME',
                            'SHELL': '/bin/bash',
                            $EXT_GALLERY_JSON
                        },
        'absolute_url': False,
        'timeout': 30
    }
}
NBCONFIG
fi

# Install Code Server launcher JL3 extension
mkdir -p $CODE_SERVER_INSTALL_LOC/lab_ext
curl -L $LAB_3_EXTENSION_DOWNLOAD_URL > $CODE_SERVER_INSTALL_LOC/lab_ext/sagemaker-jproxy-launcher-ext.tar.gz

# Install:
# - Code Server launcher extension
# - Amazon CodeWhisperer extension
# - JupyterLab S3 browser extension
# - The core JupyterLab LSP integration and whatever language servers you need (omitting autopep8
#   and yapf code formatters for Python, which don't yet have integrations per
#   https://github.com/jupyter-lsp/jupyterlab-lsp/issues/632)
# - Additional LSP plugins for formatting (black, isort) and refactoring (rope)
# - Spellchecker for markdown cells
# - Code formatting extension to bridge the LSP gap, and supported formatters
# - ipycanvas - for some specific notebook demos with interactive canvases
# - Some specific data science libraries just to improve autocomplete default suggestions:
#   - Namely sagemaker, scikit-learn
echo "Installing extensions and language tools"
pip install \
    boto3==$BOTO3_VER \
    botocore==$BOTOCORE_VER \
    jupyter-server==$JUPYTER_SERVER_VER \
    jupyterlab-server==$JUPYTERLAB_SERVER_VER \
    $CODE_SERVER_INSTALL_LOC/lab_ext/sagemaker-jproxy-launcher-ext.tar.gz \
    amazon-codewhisperer-jupyterlab-ext \
    ipycanvas \
    jupyterlab-code-formatter black isort \
    jupyterlab-lsp \
    jupyterlab-s3-browser \
    jupyterlab-spellchecker \
    'python-lsp-server[flake8,mccabe,pycodestyle,pydocstyle,pyflakes,pylint,rope]' \
    sagemaker \
    scikit-learn

# Some LSP language servers install via JS, not Python. For full list of language servers see:
# https://jupyterlab-lsp.readthedocs.io/en/latest/Language%20Servers.html
# Could we do jlpm global add? https://github.com/jupyter-lsp/jupyterlab-lsp/issues/804
jlpm add --dev bash-language-server dockerfile-language-server-nodejs

# CodeWhisperer needs to be explicitly enabled after install:
jupyter server extension enable amazon_codewhisperer_jupyterlab_ext

# Code Server extension needs jupyterlab-server-proxy disabled:
jupyter labextension disable jupyterlab-server-proxy

# Improve autocomplete source links by symlinking /opt packages from local folder and allowing
# opening of these symlinked files (outside the user home directory):
mkdir -p .lsp_symlink
rm -f .lsp_symlink/opt
ln -s /opt .lsp_symlink/opt
echo yes | jupyter server --generate-config
sed -i '1i c.ContentsManager.allow_hidden = True' .jupyter/jupyter_server_config.py

# This 'continuousHinting' configuration is optional, to make LSP "extra-helpful" by default:
CMP_CONFIG_DIR=.jupyter/lab/user-settings/@krassowski/jupyterlab-lsp/
CMP_CONFIG_FILE=completion.jupyterlab-settings
CMP_CONFIG_PATH="$CMP_CONFIG_DIR/$CMP_CONFIG_FILE"
if test -f $CMP_CONFIG_PATH; then
    echo "jupyterlab-lsp config file already exists: Skipping default config setup"
else
    echo "Setting continuous hinting to enabled by default"
    mkdir -p $CMP_CONFIG_DIR
    echo '{ "continuousHinting": true }' > $CMP_CONFIG_PATH
fi

# Similarly can set other configurations. Note:
# - Line width is unfortunately configured separately for several of these plugins.
# - You could enable `"formatOnSave": true` alongside the "black" and "isort" settings, to
#   automatically format code on save, but this also happens (and can trigger error dialogs)
#   whenever Jupyter saves a regular checkpoint of your notebook with potentially invalid /
#   incomplete Python syntax... So we haven't enabled it here to avoid this annoyance.
FMT_CONFIG_DIR=~/.jupyter/lab/user-settings/@ryantam626/jupyterlab_code_formatter
FMT_CONFIG_FILE=settings.jupyterlab-settings
FMT_CONFIG_PATH="$FMT_CONFIG_DIR/$FMT_CONFIG_FILE"
if test -f $FMT_CONFIG_PATH; then
    echo "jupyterlab-code-formatter config file already exists: Skipping default config setup"
else
    echo "Configuring jupyterlab-code-formatter line width"
    mkdir -p $FMT_CONFIG_DIR
    cat > $FMT_CONFIG_PATH <<EOF
{"black": {"line_length": 100}, "isort": {"line_length": 100}}
EOF
fi
echo "Configuring pycodestyle linter max line width"
mkdir -p ~/.config
cat > ~/.config/pycodestyle <<EOF
[pycodestyle]
max-line-length = 100
EOF

conda deactivate

# Once components are installed and configured, restart Jupyter to make sure everything propagates:
echo "Restarting Jupyter server..."
restart-jupyter-server
