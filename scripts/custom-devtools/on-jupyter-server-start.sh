#!/bin/bash
# Install and configure assistive IDE tools *if* running high enough JupyterLab version (v3)
#
# This script sets up:
# - Amazon CodeWhisperer
# - JupyterLab S3 browser extension
# - Code completion, continuous hinting, hover tips, code formatting, and markdown spell-checking
#   via jupyterlab-lsp
# - ipycanvas - A library for drawing interactive canvases in notebooks
#
# TODO: Consider adding other exts:
#   jupyterlab-execute-time, jupyterlab-skip-traceback, jupyterlab-unfold, stickyland?

set -eu

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

# Install:
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
# TODO: Could we do jlpm global add? https://github.com/jupyter-lsp/jupyterlab-lsp/issues/804
jlpm add --dev bash-language-server@"<5.0.0" dockerfile-language-server-nodejs

# CodeWhisperer needs to be explicitly enabled after install:
jupyter server extension enable amazon_codewhisperer_jupyterlab_ext

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
