#!/usr/bin/env bash
# Expand CIDR ranges and IP ranges with optional formatting modes
set -e

show_help() {
cat << 'EOF'
cidrmoo - CIDR and IP range expander
Usage:
  cidrmoo <CIDR>
  cidrmoo -r <START-END>
Examples:
  cidrmoo 192.168.1.0/24
  cidrmoo 192.168.1.0/24 -o hosts.txt
  cidrmoo -r 192.168.1.10-192.168.1.20
  cidrmoo 192.168.1.0/24 --burp
  cidrmoo 192.168.1.0/24 --burp --scheme https
  cidrmoo 192.168.1.0/24 --nessus
  cidrmoo 192.168.1.0/30 --crunch
  cidrmoo 192.168.1.0/30 --crunch --comma
EOF
}

ip_to_int() {
    local a b c d
    IFS=. read -r a b c d <<< "$1"
    echo $(( (a << 24) | (b << 16) | (c << 8) | d ))
}

int_to_ip() {
    echo "$(( ($1 >> 24) & 255 )).$(( ($1 >> 16) & 255 )).$(( ($1 >> 8) & 255 )).$(( $1 & 255 ))"
}

expand_cidr() {
    local ip="${1%/*}"
    local prefix="${1#*/}"
    local ip_int mask network broadcast first last

    ip_int=$(ip_to_int "$ip")

    if [[ "$prefix" -eq 32 ]]; then
        int_to_ip "$ip_int"
        return
    fi

    mask=$(( (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF ))
    network=$(( ip_int & mask ))
    broadcast=$(( network | (~mask & 0xFFFFFFFF) ))

    if [[ "$prefix" -eq 31 ]]; then
        first=$network
        last=$broadcast
    else
        first=$(( network + 1 ))
        last=$(( broadcast - 1 ))
    fi

    for (( i = first; i <= last; i++ )); do
        int_to_ip "$i"
    done
}

expand_range() {
    local start_int end_int
    start_int=$(ip_to_int "$1")
    end_int=$(ip_to_int "$2")
    for (( i = start_int; i <= end_int; i++ )); do
        int_to_ip "$i"
    done
}

BURP=0 NESSUS=0 CRUNCH=0 COMMA=0 RANGE=0
SCHEME="http" OUTPUT="" TARGET=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)   show_help; exit 0 ;;
        -r|--range)  RANGE=1;     shift ;;
        --burp)      BURP=1;      shift ;;
        --nessus)    NESSUS=1;    shift ;;
        --crunch)    CRUNCH=1;    shift ;;
        --comma)     COMMA=1;     shift ;;
        --scheme)    SCHEME="$2"; shift 2 ;;
        -o|--output) OUTPUT="$2"; shift 2 ;;
        *)           TARGET="$1"; shift ;;
    esac
done

[[ -z "$TARGET" ]] && { show_help; exit 1; }

if [[ "$RANGE" -eq 1 ]]; then
    mapfile -t RESULTS < <(expand_range "${TARGET%-*}" "${TARGET#*-}")
else
    mapfile -t RESULTS < <(expand_cidr "$TARGET")
fi

format_output() {
    if [[ "$BURP" -eq 1 ]]; then
        for ip in "${RESULTS[@]}"; do echo "${SCHEME}://${ip}"; done
    elif [[ "$CRUNCH" -eq 1 ]]; then
        local sep=$([[ "$COMMA" -eq 1 ]] && echo ", " || echo " ")
        local joined
        joined=$(printf "%s${sep}" "${RESULTS[@]}")
        echo "${joined%"${sep}"}"
    else
        printf "%s\n" "${RESULTS[@]}"
    fi
}

output=$(format_output)
echo "$output"

if [[ -n "$OUTPUT" ]]; then
    echo "$output" > "$OUTPUT"
    echo
    echo "Saved output to $OUTPUT"
fi
