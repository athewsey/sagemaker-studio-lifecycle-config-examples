#!/bin/bash
# TEMPORARY fix for VPC DNS mis-configuration preventing connection to service endpoints
#
# Remove this after fixing ML VPC to properly route your existing service VPCes (in diff account)

# Immediately exit on error (e) and treat undefined shell vars as errors (u):
set -eu

# if [ "$(id -u)" != "0" ]; then
#   EXECUTOR="sudo -u root -i"
# else
#   EXECUTOR="eval"
# fi

# TODO: UPLOAD THE DNSFIX.PY TO S3
DNSFIX_SCRIPT_URI='s3://.../.../dnsfix.py'

# TODO: ADD EC2 SERVICE HOSTFILE ENTRIES FIRST
# Can't call the DescribeVPCEndpoints APIs in Python if you don't have the EC2 endpoint set up
sudo -u root -i <<EOS
cat >> /etc/hosts <<EOF
# HOSTS GO HERE
EOF
EOS

# Activate the conda environment where Jupyter (and proper Python3/etc) is installed:
eval "$(conda shell.bash hook)"
conda activate studio

aws s3 cp $DNSFIX_SCRIPT_URI .dnsfix/dnsfix.py
chmod u+x .dnsfix/dnsfix.py
cp /etc/hosts /tmp/dnsfix_hosts
python .dnsfix/dnsfix.py /tmp/dnsfix_hosts
sudo cp /tmp/dnsfix_hosts /etc/hosts
rm /tmp/dnsfix_hosts
echo "Hosts updated"