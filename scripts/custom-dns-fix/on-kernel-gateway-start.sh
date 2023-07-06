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

# TODO: ADD EC2 SERVICE HOSTFILE ENTRIES MANUALLY FIRST
# Can't call the DescribeVPCEndpoints APIs in Python if you don't have the EC2 endpoint set up
sudo -u root -i <<EOS
cat >> /etc/hosts <<EOF
# HOSTS GO HERE
EOF
EOS

# Probably(?) all our target kernels have a conda setup and `base` offers python 3 + boto3:
eval "$(conda shell.bash hook)"
conda activate base

aws s3 cp $DNSFIX_SCRIPT_URI /tmp/dnsfix.py
chmod u+x /tmp/dnsfix.py
TMPFILE_SUFFIX=`date +%s`
TMPFILE="/tmp/dnsfix_hosts_${TMPFILE_SUFFIX}"
cp /etc/hosts $TMPFILE
python .dnsfix/dnsfix.py $TMPFILE

if [ "$(id -u)" != "0" ]; then
  sudo cp $TMPFILE /etc/hosts
else
  cp $TMPFILE /etc/hosts
fi
rm $TMPFILE
echo "Hosts updated"
