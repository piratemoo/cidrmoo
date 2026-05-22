#!/usr/bin/env bash

# cidrmoo - bash edition
# Expand CIDR ranges and IP ranges with optional formatting modes

set -e

show_help() {
cat << EOF

cidrmoo - CIDR and IP range expander

Usage:
  cidrmoo <CIDR>
  cidrmoo -r <START-END>

Examples:

  CIDR:
    cidrmoo 192.168.1.0/24

  CIDR to file:
    cidrmoo 192.168.1.0/24 -o hosts.txt

  Range mode:
    cidrmoo -r 192.168.1.10-192.168.1.20

  Burp formatting:
    cidrmoo 192.168.1.0/24 --burp

  Burp HTTPS formatting:
    cidrmoo 192.168.1.0/24 --burp --scheme https

  Nessus formatting:
    cidrmoo 192.168.1.0/24 --nessus

  Crunch formatting:
    cidrmoo 192.168.1.0/30 --crunch
    Output:
      192.168.1.1 192.168.1.2

  Crunch formatting with commas:
    cidrmoo 192.168.1.0/30 --crunch --comma
    Output:
      192.168.1.1, 192.168.1.2,

EOF
}

ip_to_int() {
    local IFS=.
    read -r a b c d <<< "$1"
    echo $(( (a << 24) + (b << 16) + (c << 8) + d ))
}

int_to_ip() {
    local ip=$1
    echo "$(( (ip >> 24) & 255 )).$(( (ip >> 16) & 255 )).$(( (ip >> 8) & 255 )).$(( ip & 255 ))"
}

expand_range() {
    local start="$1"
    local end="$2"

    local start_int
    local end_int

    start_int=$(ip_to_int "$start")
    end_int=$(ip_to_int "$end")

    for (( ip=start_int; ip<=end_int; ip++ )); do
        int_to_ip "$ip"
    done
}

expand_cidr() {
    python3 - << EOF
import ipaddress
network = ipaddress.ip_network("$1", strict=False)
for ip in network.hosts():
    print(ip)
EOF
}

BURP=0
NESSUS=0
CRUNCH=0
COMMA=0
RANGE=0
SCHEME="http"
OUTPUT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -r|--range)
            RANGE=1
            shift
            ;;
        --burp)
            BURP=1
            shift
            ;;
        --nessus)
            NESSUS=1
            shift
            ;;
        --crunch)
            CRUNCH=1
            shift
            ;;
        --comma)
            COMMA=1
            shift
            ;;
        --scheme)
            SCHEME="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT="$2"
            shift 2
            ;;
        *)
            TARGET="$1"
            shift
            ;;
    esac
done

if [[ -z "$TARGET" ]]; then
    show_help
    exit 1
fi

RESULTS=()

if [[ "$RANGE" -eq 1 ]]; then
    START_IP="${TARGET%-*}"
    END_IP="${TARGET#*-}"

    while IFS= read -r ip; do
        RESULTS+=("$ip")
    done < <(expand_range "$START_IP" "$END_IP")

else
    while IFS= read -r ip; do
        RESULTS+=("$ip")
    done < <(expand_cidr "$TARGET")
fi

FINAL_OUTPUT=()

if [[ "$BURP" -eq 1 ]]; then

    for ip in "${RESULTS[@]}"; do
        FINAL_OUTPUT+=("${SCHEME}://${ip}")
    done

elif [[ "$NESSUS" -eq 1 ]]; then

    FINAL_OUTPUT+=("$TARGET")

elif [[ "$CRUNCH" -eq 1 ]]; then

    LINE=""

    for ip in "${RESULTS[@]}"; do
        if [[ "$COMMA" -eq 1 ]]; then
            LINE+="${ip}, "
        else
            LINE+="${ip} "
        fi
    done

    FINAL_OUTPUT+=("$LINE")

else

    FINAL_OUTPUT=("${RESULTS[@]}")

fi

for line in "${FINAL_OUTPUT[@]}"; do
    echo "$line"
done

if [[ -n "$OUTPUT" ]]; then
    printf "%s\n" "${FINAL_OUTPUT[@]}" > "$OUTPUT"
    echo
    echo "Saved output to $OUTPUT"
fi
