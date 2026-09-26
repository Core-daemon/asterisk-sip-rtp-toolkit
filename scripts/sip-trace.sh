#!/usr/bin/env bash

# Asterisk SIP/RTP Toolkit
# SIP Trace Utility
#
# Author: Mohammad Sorower Jahan
# Repository:
# https://github.com/Core-daemon/asterisk-sip-rtp-toolkit
#
# Read-only packet capture utility for SIP troubleshooting.
#
# IMPORTANT:
# SIP captures may contain telephone numbers, IP addresses,
# SIP usernames, Call-IDs and authentication information.
# Never publish a production capture without reviewing
# and sanitising it first.

set -u

DURATION=60
INTERFACE="any"
HOST_FILTER=""
OUTPUT_DIR="./captures"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
OUTPUT_FILE="sip-trace-${TIMESTAMP}.pcap"

usage()
{
    cat <<EOF

Asterisk SIP Trace Utility

Usage:
  sudo $0 [options]

Options:

  -i, --interface IFACE
      Network interface to capture.
      Default: any

  -d, --duration SECONDS
      Capture duration in seconds.
      Default: 60

  -H, --host IP
      Restrict capture to a specific SIP server/provider IP.

  -o, --output FILE
      Output PCAP filename.

  -h, --help
      Show this help.

Examples:

  sudo $0

  sudo $0 --duration 30

  sudo $0 --interface eth0 --duration 60

  sudo $0 --host 203.0.113.10 --duration 30

  sudo $0 --interface ens18 --host 203.0.113.10

EOF
}

command_exists()
{
    command -v "$1" >/dev/null 2>&1
}

while [ $# -gt 0 ]; do

    case "$1" in

        -i|--interface)
            INTERFACE="$2"
            shift 2
            ;;

        -d|--duration)
            DURATION="$2"
            shift 2
            ;;

        -H|--host)
            HOST_FILTER="$2"
            shift 2
            ;;

        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;

        -h|--help)
            usage
            exit 0
            ;;

        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;

    esac

done

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] Packet capture normally requires root privileges."
    echo
    echo "Run:"
    echo "sudo $0"
    exit 1
fi

if ! command_exists tcpdump; then
    echo "[ERROR] tcpdump is not installed."
    echo
    echo "Install it using your Linux distribution package manager."
    exit 1
fi

if ! [[ "$DURATION" =~ ^[0-9]+$ ]]; then
    echo "[ERROR] Duration must be a number."
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

if [[ "$OUTPUT_FILE" != */* ]]; then
    OUTPUT_FILE="${OUTPUT_DIR}/${OUTPUT_FILE}"
fi

echo
echo "============================================================"
echo "                Asterisk SIP Trace"
echo "============================================================"
echo
echo "Interface : $INTERFACE"
echo "Duration  : $DURATION seconds"

if [ -n "$HOST_FILTER" ]; then
    echo "Host      : $HOST_FILTER"
else
    echo "Host      : all SIP hosts"
fi

echo "Output    : $OUTPUT_FILE"
echo

#
# Check interface
#

if [ "$INTERFACE" != "any" ]; then

    if command_exists ip; then

        if ! ip link show "$INTERFACE" >/dev/null 2>&1; then
            echo "[ERROR] Interface '$INTERFACE' does not exist."
            exit 1
        fi

    fi

fi

#
# Display detected local addresses
#

echo "Local network addresses:"
echo

if command_exists ip; then

    ip -brief addr 2>/dev/null || true

elif command_exists ifconfig; then

    ifconfig 2>/dev/null | head -40

fi

echo
echo "------------------------------------------------------------"
echo "Capture filter"
echo "------------------------------------------------------------"

#
# SIP ports
#
# 5060 = common SIP UDP/TCP
# 5061 = commonly SIP TLS
#
# Port 4569 is IAX2 and intentionally not included here because
# this tool is specifically intended for SIP signalling.
#

FILTER="port 5060 or port 5061"

if [ -n "$HOST_FILTER" ]; then
    FILTER="host ${HOST_FILTER} and (${FILTER})"
fi

echo "$FILTER"

echo
echo "------------------------------------------------------------"
echo "Security notice"
echo "------------------------------------------------------------"
echo
echo "The capture may contain sensitive SIP information."
echo "Do not upload production PCAP files publicly without review."
echo
echo "Starting capture..."
echo

#
# Capture
#

if command_exists timeout; then

    timeout "$DURATION" \
        tcpdump \
        -i "$INTERFACE" \
        -nn \
        -s 0 \
        -w "$OUTPUT_FILE" \
        "$FILTER"

    TCPDUMP_STATUS=$?

    #
    # timeout normally returns 124 when the requested capture
    # duration has completed.
    #

    if [ "$TCPDUMP_STATUS" -ne 0 ] &&
       [ "$TCPDUMP_STATUS" -ne 124 ]; then

        echo
        echo "[ERROR] tcpdump returned status $TCPDUMP_STATUS."
        exit "$TCPDUMP_STATUS"

    fi

else

    echo "[WARN] 'timeout' command is unavailable."
    echo
    echo "Press Ctrl+C manually after approximately"
    echo "$DURATION seconds."
    echo

    tcpdump \
        -i "$INTERFACE" \
        -nn \
        -s 0 \
        -w "$OUTPUT_FILE" \
        "$FILTER"

fi

echo
echo "============================================================"
echo " Capture complete"
echo "============================================================"
echo

if [ -f "$OUTPUT_FILE" ]; then

    SIZE="$(du -h "$OUTPUT_FILE" 2>/dev/null | awk '{print $1}')"

    echo "File : $OUTPUT_FILE"
    echo "Size : ${SIZE:-unknown}"

else

    echo "[WARN] Expected capture file was not created."
    exit 1

fi

echo
echo "------------------------------------------------------------"
echo "Quick capture summary"
echo "------------------------------------------------------------"
echo

tcpdump \
    -nn \
    -r "$OUTPUT_FILE" \
    -c 20 \
    2>/dev/null || true

echo
echo "------------------------------------------------------------"
echo "Useful follow-up commands"
echo "------------------------------------------------------------"
echo

echo "Read capture:"
echo
echo "  tcpdump -nn -r \"$OUTPUT_FILE\""
echo

echo "Display SIP text where possible:"
echo
echo "  tcpdump -A -nn -r \"$OUTPUT_FILE\""
echo

if command_exists sngrep; then

    echo "Open capture with sngrep:"
    echo
    echo "  sngrep -I \"$OUTPUT_FILE\""
    echo

fi

echo "Open the PCAP with Wireshark for detailed SIP/SDP analysis."
echo

echo "IMPORTANT:"
echo "Review and sanitise captures before sharing them with others."
echo
