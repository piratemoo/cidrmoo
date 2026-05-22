#!/usr/bin/env python3

import ipaddress
import sys
import argparse

def ip_class(ip):
    first_octet = int(str(ip).split('.')[0])

    if 1 <= first_octet <= 126:
        return "A"
    elif 128 <= first_octet <= 191:
        return "B"
    elif 192 <= first_octet <= 223:
        return "C"
    elif 224 <= first_octet <= 239:
        return "D (Multicast)"
    elif 240 <= first_octet <= 254:
        return "E (Reserved)"
    else:
        return "Unknown"

def expand_cidr(value):
    network = ipaddress.ip_network(value, strict=False)
    hosts = list(network.hosts())

    info = {
        "type": "CIDR",
        "class": ip_class(network.network_address),
        "subnet": str(network.netmask),
        "network": str(network.network_address),
        "broadcast": str(network.broadcast_address),
        "total": len(hosts),
        "original": value
    }

    return [str(ip) for ip in hosts], info

def expand_range(value):
    start_ip, end_ip = value.split("-", 1)

    start = ipaddress.ip_address(start_ip.strip())
    end = ipaddress.ip_address(end_ip.strip())

    if int(start) > int(end):
        raise ValueError("Start IP is greater than end IP")

    ips = [
        str(ipaddress.ip_address(ip))
        for ip in range(int(start), int(end) + 1)
    ]

    info = {
        "type": "Range",
        "class": ip_class(start),
        "start": str(start),
        "end": str(end),
        "total": len(ips),
        "original": value
    }

    return ips, info

def cidrmoo(value, is_range=False):
    try:
        if is_range:
            return expand_range(value)

        return expand_cidr(value)

    except ValueError as e:
        print(f"Error: {e}")
        return [], None

def format_burp(ips, scheme):
    return [f"{scheme}://{ip}" for ip in ips]

def format_nessus(info):
    if info["type"] == "CIDR":
        return [info["original"]]

    return [f"{info['start']}-{info['end']}"]

def format_crunch(results, comma=False):
    # Output all IPs on a single line

    if comma:
        return [" ".join([f"{ip}," for ip in results])]

    return [" ".join(results)]

def main():

    examples = '''
Examples:

  CIDR:
    python3 cidrmoo.py 192.168.1.0/24

  CIDR to file:
    python3 cidrmoo.py 192.168.1.0/24 -o hosts.txt

  Range mode:
    python3 cidrmoo.py -r 192.168.1.10-192.168.1.20

  Burp formatting:
    python3 cidrmoo.py 192.168.1.0/24 --burp

  Burp HTTPS formatting:
    python3 cidrmoo.py 192.168.1.0/24 --burp --scheme https

  Nessus formatting:
    python3 cidrmoo.py 192.168.1.0/24 --nessus

  Crunch formatting:
    python3 cidrmoo.py 192.168.1.0/30 --crunch
    Output:
      192.168.1.1 192.168.1.2

  Crunch formatting with commas:
    python3 cidrmoo.py 192.168.1.0/30 --crunch --comma
    Output:
      192.168.1.1, 192.168.1.2,
'''

    parser = argparse.ArgumentParser(
        description="cidrmoo - CIDR and IP range expander",
        epilog=examples,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument(
        "target",
        help="CIDR or IP range target"
    )

    parser.add_argument(
        "-r",
        "--range",
        action="store_true",
        help="Treat target as an IP range"
    )

    parser.add_argument(
        "-o",
        "--output",
        help="Save output to file",
        default=None
    )

    parser.add_argument(
        "--burp",
        action="store_true",
        help="Format output for Burp Suite"
    )

    parser.add_argument(
        "--scheme",
        choices=["http", "https"],
        default="http",
        help="Scheme for Burp formatting"
    )

    parser.add_argument(
        "--nessus",
        action="store_true",
        help="Format output for Nessus"
    )

    parser.add_argument(
        "--crunch",
        action="store_true",
        help="Output all IPs on one line separated by spaces"
    )

    parser.add_argument(
        "--comma",
        action="store_true",
        help="Add commas after each IP (used with --crunch)"
    )

    args = parser.parse_args()

    ips, info = cidrmoo(args.target, args.range)

    if not info:
        sys.exit(1)

    # Formatting modes
    if args.burp:
        results = format_burp(ips, args.scheme)

    elif args.nessus:
        results = format_nessus(info)

    elif args.crunch:
        results = format_crunch(ips, args.comma)

    else:
        results = ips

    # Metadata
    if not args.burp and not args.nessus and not args.crunch:

        print("\n[cidrmoo]")
        print(f"Input Type      : {info['type']}")
        print(f"Address Class   : {info['class']}")
        print(f"Total IPs       : {info['total']}")

        if info["type"] == "CIDR":
            print(f"Subnet Mask     : {info['subnet']}")
            print(f"Network Address : {info['network']}")
            print(f"Broadcast Addr  : {info['broadcast']}")

        else:
            print(f"Start IP        : {info['start']}")
            print(f"End IP          : {info['end']}")

        print("\nIPs:")
        print("-" * 18)

    for item in results:
        print(item)

    # Output file
    if args.output:
        try:
            with open(args.output, "w") as f:
                for item in results:
                    f.write(item + "\n")

            print(f"\nSaved {len(results)} result(s) to {args.output}")

        except Exception as e:
            print(f"\nError saving file: {e}")

if __name__ == "__main__":
    main()
