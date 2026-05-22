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

ip_class() {
    local first="${1%%.*}"
    if   (( first >= 1   && first <= 126 )); then echo "A"
    elif (( first >= 128 && first <= 191 )); then echo "B"
    elif (( first >= 192 && first <= 223 )); then echo "C"
    elif (( first >= 224 && first <= 239 )); then echo "D (Multicast)"
    elif (( first >= 240 && first <= 254 )); then echo "E (Reserved)"
    else echo "Unknown"
    fi
}

# Populated by expand_cidr / expand_range
INFO_TYPE="" INFO_CLASS="" INFO_TOTAL=""
INFO_SUBNET="" INFO_NETWORK="" INFO_BROADCAST=""
INFO_START="" INFO_END=""

expand_cidr() {
    local ip="${1%/*}"
    local prefix="${1#*/}"
    local ip_int mask network broadcast first last

    ip_int=$(ip_to_int "$ip")

    if [[ "$prefix" -eq 32 ]]; then
        INFO_TYPE="CIDR"
        INFO_CLASS=$(ip_class "$ip")
        INFO_SUBNET="255.255.255.255"
        INFO_NETWORK="$ip"
        INFO_BROADCAST="$ip"
        int_to_ip "$ip_int"
        return
    fi

    mask=$(( (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF ))
    network=$(( ip_int & mask ))
    broadcast=$(( network | (~mask & 0xFFFFFFFF) ))

    INFO_TYPE="CIDR"
    INFO_CLASS=$(ip_class "$ip")
    INFO_SUBNET=$(int_to_ip "$mask")
    INFO_NETWORK=$(int_to_ip "$network")
    INFO_BROADCAST=$(int_to_ip "$broadcast")

    if [[ "$prefix" -eq 31 ]]; then
        first=$network; last=$broadcast
    else
        first=$(( network + 1 )); last=$(( broadcast - 1 ))
    fi

    for (( i = first; i <= last; i++ )); do
        int_to_ip "$i"
    done
}

expand_range() {
    local start_int end_int
    start_int=$(ip_to_int "$1")
    end_int=$(ip_to_int "$2")

    if (( start_int > end_int )); then
        echo "Error: Start IP is greater than end IP" >&2
        exit 1
    fi

    INFO_TYPE="Range"
    INFO_CLASS=$(ip_class "$1")
    INFO_START="$1"
    INFO_END="$2"

    for (( i = start_int; i <= end_int; i++ )); do
        int_to_ip "$i"
    done
}

format_output() {
    if [[ "$BURP" -eq 1 ]]; then
        for ip in "${RESULTS[@]}"; do echo "${SCHEME}://${ip}"; done

    elif [[ "$NESSUS" -eq 1 ]]; then
        if [[ "$INFO_TYPE" == "CIDR" ]]; then
            echo "$TARGET"
        else
            echo "${INFO_START}-${INFO_END}"
        fi

    elif [[ "$CRUNCH" -eq 1 ]]; then
        local sep=$([[ "$COMMA" -eq 1 ]] && echo ", " || echo " ")
        local joined
        joined=$(printf "%s${sep}" "${RESULTS[@]}")
        echo "${joined%"${sep}"}"

    else
        printf "%s\n" "${RESULTS[@]}"
    fi
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

INFO_TOTAL="${#RESULTS[@]}"

# Metadata header — only in default mode
if [[ "$BURP" -eq 0 && "$NESSUS" -eq 0 && "$CRUNCH" -eq 0 ]]; then
    echo
    echo "[cidrmoo]"
    printf "%-16s: %s\n" "Input Type"    "$INFO_TYPE"
    printf "%-16s: %s\n" "Address Class" "$INFO_CLASS"
    printf "%-16s: %s\n" "Total IPs"     "$INFO_TOTAL"

    if [[ "$INFO_TYPE" == "CIDR" ]]; then
        printf "%-16s: %s\n" "Subnet Mask"     "$INFO_SUBNET"
        printf "%-16s: %s\n" "Network Address" "$INFO_NETWORK"
        printf "%-16s: %s\n" "Broadcast Addr"  "$INFO_BROADCAST"
    else
        printf "%-16s: %s\n" "Start IP" "$INFO_START"
        printf "%-16s: %s\n" "End IP"   "$INFO_END"
    fi

    echo
    echo "IPs:"
    echo "------------------"
fi

output=$(format_output)
echo "$output"

if [[ -n "$OUTPUT" ]]; then
    echo "$output" > "$OUTPUT"
    echo
    echo "Saved ${INFO_TOTAL} result(s) to $OUTPUT"
fi
