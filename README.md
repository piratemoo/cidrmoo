# cidrmoo

`cidrmoo` a lightweight script for expanding CIDR notation/IP ranges into usable host lists with multiple output formats.

### Features
- Expand CIDR ranges
- Expand IP ranges with `-r`
- Export raw IPs to files
- Crunch formatting for single-line target blobs
- Optional comma-separated output

Displays: Address class, Subnet mask, Network/Broadcast address, Total hosts

```text
usage: cidrmoo.py target [-r] [-o OUTPUT] [--burp] [--scheme {http,https}] [--nessus] 

target                  CIDR or IP range target

options:
  -h, --help            show this help message and exit
  -r, --range           Treat target as an IP range (example: 192.168.1.10-192.168.1.20)
  -o, --output OUTPUT   Save output to file
  --burp                Format output for Burp Suite
  --scheme {http,https}
                        Scheme for Burp formatting
  --nessus              Format output for Nessus
```

Examples:

Expand IP range and export to file <br>
`cidrmoo -r 192.168.1.10-192.168.1.20 -o hosts.txt`

Burp-style HTTPS formatting <br>
`cidrmoo 10.0.0.0/30 --burp --scheme https`

Crunch formatting with commas <br>
`cidrmoo 10.0.0.0/30 --crunch --comma`
