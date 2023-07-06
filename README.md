# (CUSTOM) SageMaker Studio Lifecycle Configuration Samples

> ⚠️ This `custom` branch is a holding ground for scripts & tools that I've found useful but aren't quite ready for (or am not planning to PR to) the upstream repository. Use with caution & don't merge into `main`!

### Custom/Non-Standard Scripts

* [custom-check-jl-version](scripts/custom-check-jl-version) - A snippet showing ways to detect and branch on the current JupyterLab version in Studio LCCs, and which conda environments & JupyterServer restart tools to use in each one.
* [custom-devtools](scripts/custom-devtools) - Similar to [install-lsp-features](scripts/install-lsp-features), but extended with some other useful developer tooling including CodeWhisperer, S3 browser.
* [custom-devtools-autoshutdown](scripts/custom-devtools-autoshutdown) - Similar to [custom-devtools](scripts/custom-devtools), but combined with [install-autoshutdown-server-extension](scripts/install-autoshutdown-server-extension)
* [custom-devtools-codeserver](scripts/custom-devtools-codeserver) - Extension of [custom-devtools](scripts/custom-devtools) that also [installs (VS)Code Server on Studio](https://github.com/aws-samples/amazon-sagemaker-codeserver)
    * ⚠️ **Known issue:** In recent tests, this one breaks the 'Launcher' (will not show at all). However, Code is still accessible at `/jupyter/default/codeserver` and notebooks/etc can be created through *File > New*
* [custom-dns-fix](scripts/custom-dns-fix) - A horrible temporary workaround for a broken VPC DNS environment. You don't want to use this.
* [custom-install-s3-browser-extension](scripts/custom-install-s3-browser-extension) - This visual S3 browser extension is pretty easy to install on JupyterLab v3. I was trying to also make it work on JLv1 (for a script that's portable between the two) but never quite got it working.

### Overview

A collection of sample scripts customizing SageMaker Studio Applications using Lifecycle Configuration

Lifecycle Configurations provide a mechanism to customize the Jupyter Server and Kernel Application instances via shell scripts that are executed during the lifecycle of the application.

#### Sample Scripts

* [git-clone-repo](scripts/git-clone-repo) - Checks out a Git repository under the user's home folder automatedly when the Jupter server starts
* [install-autoshutdown-server-extension](scripts/install-autoshutdown-server-extension) (Recommended) - Installs only the server part of idle-kernel shutdown extension. No external dependencies to install, recommended to use in VPCOnly mode with restricted Internet connectivity. Idle timelimit has to be set using Life Cycle Configuration script.
* [install-autoshutdown-extension](scripts/install-autoshutdown-extension) - Installs the auto idle-kernel shutdown extension on the Jupyter Server. This install allows users to set idle timeout limit using the UI. ***Note***: *The UI plugin is only compatible with JupyterLab v1.0. See [JupyterLab versioning](https://docs.aws.amazon.com/sagemaker/latest/dg/studio-jl.html) for JupyterLab versions in SageMaker Studio.*
* [install-lsp-features](scripts/install-lsp-features) - Installs coding assistance tools to enable features like auto-completion, linting, and hover suggestions in Studio JupyterLab v3+.
* [disable-automatic-kernel-start](disable-automatic-kernel-start) - Disables automatic starting of kernel when opening notebooks. Only works with Studio JupyterLab v3.3+.
* [install-pip-package-on-kernel](scripts/install-pip-package-on-kernel) - Installs a python package with pip on a Studio Kernel
* [set-git-config](scripts/set-git-config) - This script sets the username and email address in Git config.
* [set-git-credentials](scripts/set-git-credentials) - Adds the user's git credentials to Secret Manager and configures git to fetch the credentials from there when needed
* [set-proxy-settings](scripts/set-proxy-settings) - Configures HTTP and HTTPS proxy settings on jupter server and on the Studio kernels.

#### Developing LCC Scripts for SageMaker Studio

For best practicies, please check the [DEVELOPMENT.md](DEVELOPMENT.md).
