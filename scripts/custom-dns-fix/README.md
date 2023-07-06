# Altering Studio notebook DNS with host file overrides

You almost certainly don't need to do this. Even if you do it, you'll find the DNS is updated on
your Studio environment itself but not any training/processing/etc jobs you create.

I used it once to temporarily get Studio notebooks able to call AWS Services in an environment with
a mis-configured VPC DNS. The most likely cause for this is that your organization routes all
VPC-to-service traffic through a central services VPC, but your SageMaker PoC VPC is not yet
connected to the services VPC so is trying to contact unreachable IPs.

Pre-requisites are:
- You've got an S3 Gateway Endpoint in your VPC and DNS for that is already working correctly
- You've created interface endpoints for other AWS services you want to access, but DNS isn't
picking them up
- You've uploaded the [dnsfix.py](./dnsfix.py) to S3 and configured its location in the LCC scripts
- You've manually entered the IPs for your VPC Endpoint for EC2 Service into the scripts

The provided LCCs will download the Python script from S3, which will query the Amazon EC2 APIs to
find all VPC Endpoints in your VPC and create `/etc/hosts` file entries for each of them -
overriding the (broken) VPC DNS to reach these services.

Note that even using this solution, you may struggle to reach non-regional (global) services like
IAM: Because the default domain name they reach out to won't match the hostfile entry.

Again... Just fix your VPC's DNS settings instead ;-)
