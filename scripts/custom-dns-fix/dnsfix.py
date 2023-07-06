"""Generate DNS hosts file entries for all VPC Endpoints in the current account/region
"""
# Python Built-Ins:
import argparse

# External Dependencies:
import boto3

ec2 = boto3.client("ec2")

def parse_args():
    parser = argparse.ArgumentParser(
            description="Generate DNS hosts file entries for all VPC endpoints in this region",
            epilog='Text at the bottom of help'
    )
    parser.add_argument(
        "-m", "--file-mode",
        choices=["append", "new"],
        default="append",
        help="Whether to 'append' to the target file or create 'new' file from scratch",
    )
    parser.add_argument(
        "filename",
        default="/etc/hosts",
        help="Output 'hosts' file to write to",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()

    desc_endpoints_resp = ec2.describe_vpc_endpoints()
    host_entries = []

    print("Opening /etc/hosts file...")
    with open(args.filename, "a" if args.file_mode == "append" else "w") as f:
        f.write("\n")
        for endpoint in desc_endpoints_resp["VpcEndpoints"]:
            ep_id = endpoint["VpcEndpointId"]
            ep_svc = endpoint["ServiceName"]
            if "ec2" in ep_svc.split("."):
                print(f"Skipping EC2 endpoint {ep_id}: {ep_svc}")
                continue
            if endpoint["VpcEndpointType"].lower() == "gateway":
                print(f"Skipping gateway endpoint {ep_id} for service {ep_svc}")
                continue
            if endpoint["State"].lower() != "available":
                print(
                    "Skipping endpoint %s for service %s as state is '%s'"
                    % (ep_id, ep_svc, endpoint["State"]),
                )
                continue

            try:
                ep_dns_name = next(
                    dns_entry["DnsName"]
                    for dns_entry in endpoint["DnsEntries"]
                    if not (dns_entry["DnsName"].startswith("vpce") or "*" in dns_entry["DnsName"])
                )
            except StopIteration as e:
                print(f"WARN: Using best-guess DNS entry for service {ep_svc}")
                ep_dns_name = ".".join(
                    filter(
                        lambda s: not s.startswith("vpc"),
                        endpoint["DnsEntries"][0]["DnsName"].split("."),
                    ),
                )

            enis_desc = ec2.describe_network_interfaces(
                NetworkInterfaceIds=endpoint["NetworkInterfaceIds"]
            )
            for eni in enis_desc["NetworkInterfaces"]:
                # (IPv4 only for now)
                for ip in eni["PrivateIpAddresses"]:
                    host = f"{ip['PrivateIpAddress']} {ep_dns_name}"
                    host_entries.append(host)
                    print(host)
                    f.write(host + "\n")
    print("Done")
