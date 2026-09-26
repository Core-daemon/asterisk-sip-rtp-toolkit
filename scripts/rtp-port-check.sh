#!/usr/bin/env bash

# Asterisk SIP/RTP Toolkit
# RTP Configuration and Network Check
#
# Author: Mohammad Sorower Jahan
# Repository:
# https://github.com/Core-daemon/asterisk-sip-rtp-toolkit
#
# Read-only diagnostic utility.
# It does not modify Asterisk, routing or firewall configuration.

set -u

ASTERISK_BIN="$(command -v asterisk 2>/dev/null || true)"
RTP_CONF="/etc/asterisk/rtp.conf"
PEER_IP=""

RTP_START=""
RTP_END=""

PASS_COUNT=0
WARN_COUNT=0

line()
{
    printf '%s\n' "------------------------------------------------------------"
}

section()
{
    echo
    line
    printf '%s\n' "$1"
    line
}

pass()
{
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '[PASS] %s\n' "$1"
}

warn()
{
    WARN_COUNT=$((WARN_COUNT + 1))
    printf '[WARN] %s\n' "$1"
}

info()
{
    printf '[INFO] %s\n' "$1"
}

command_exists()
{
    command -v "$1" >/dev/null 2>&1
}

usage()
{
    cat <<EOF

Asterisk RTP Port Check

Usage:

  sudo $0

Optional remote media peer:

  sudo $0 --peer 203.0.113.10

Options:

  --peer IP
      Show the Linux route that would be used to reach
      the specified RTP/media peer.

  --help
      Display this help.

This utility performs read-only checks.

EOF
}

while [ $# -gt 0 ]; do

    case "$1" in

        --peer)
            PEER_IP="${2:-}"
            shift 2
            ;;

        --help|-h)
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

echo
echo "============================================================"
echo "            Asterisk RTP Port Check"
echo "============================================================"
echo
echo "Host : $(hostname 2>/dev/null || echo unknown)"
echo "Date : $(date)"
echo

#
# Asterisk
#

section "1. Asterisk"

if [ -n "$ASTERISK_BIN" ]; then

    pass "Asterisk binary found."

    VERSION="$("$ASTERISK_BIN" -rx "core show version" 2>/dev/null | head -1 || true)"

    if [ -n "$VERSION" ]; then
        echo "$VERSION"
    else
        warn "Asterisk CLI did not respond."
    fi

else
    warn "Asterisk binary not found in PATH."
fi

#
# Runtime RTP settings
#

section "2. Asterisk RTP Runtime Settings"

if [ -n "$ASTERISK_BIN" ]; then

    RTP_RUNTIME="$("$ASTERISK_BIN" -rx "rtp show settings" 2>/dev/null || true)"

    if [ -n "$RTP_RUNTIME" ]; then

        pass "Asterisk RTP runtime information retrieved."
        echo
        printf '%s\n' "$RTP_RUNTIME"

    else

        info "'rtp show settings' did not return information."

    fi

fi

#
# rtp.conf
#

section "3. rtp.conf"

if [ -r "$RTP_CONF" ]; then

    pass "$RTP_CONF is readable."

    RTP_START="$(
        grep -Ei '^[[:space:]]*rtpstart[[:space:]]*=' "$RTP_CONF" |
        tail -1 |
        cut -d= -f2 |
        tr -d '[:space:]'
    )"

    RTP_END="$(
        grep -Ei '^[[:space:]]*rtpend[[:space:]]*=' "$RTP_CONF" |
        tail -1 |
        cut -d= -f2 |
        tr -d '[:space:]'
    )"

    echo

    grep -Ei \
        '^[[:space:]]*(rtpstart|rtpend|strictrtp|icesupport|stunaddr)[[:space:]]*=' \
        "$RTP_CONF" 2>/dev/null || true

    echo

    if [ -n "$RTP_START" ] && [ -n "$RTP_END" ]; then

        pass "Configured RTP range: $RTP_START-$RTP_END"

        if [[ "$RTP_START" =~ ^[0-9]+$ ]] &&
           [[ "$RTP_END" =~ ^[0-9]+$ ]]; then

            if [ "$RTP_START" -lt "$RTP_END" ]; then
                pass "RTP range ordering is valid."
            else
                warn "RTP start is not lower than RTP end."
            fi

            RANGE_SIZE=$((RTP_END - RTP_START + 1))
            echo "Configured UDP ports in range: $RANGE_SIZE"

        else

            warn "RTP range contains unexpected values."

        fi

    else

        warn "Could not identify both rtpstart and rtpend."

    fi

else

    warn "$RTP_CONF is not readable."

fi

#
# IP addresses
#

section "4. Local Network Addresses"

if command_exists ip; then

    ip -brief addr 2>/dev/null || ip addr show 2>/dev/null

    echo

    PRIVATE_IPS="$(
        ip -4 -o addr show 2>/dev/null |
        awk '{print $4}' |
        cut -d/ -f1 |
        grep -E \
        '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)' || true
    )"

    if [ -n "$PRIVATE_IPS" ]; then

        info "Private IPv4 address detected."

        echo
        printf '%s\n' "$PRIVATE_IPS"

        echo
        info "For external RTP, verify NAT and SDP address handling."

    fi

else

    warn "'ip' command not found."

fi

#
# Routing
#

section "5. Routing"

if command_exists ip; then

    ip route show 2>/dev/null

    echo

    DEFAULT_ROUTE="$(ip route show default 2>/dev/null || true)"

    if [ -n "$DEFAULT_ROUTE" ]; then
        pass "Default IPv4 route detected."
        echo "$DEFAULT_ROUTE"
    else
        warn "No default IPv4 route detected."
    fi

else

    warn "Linux iproute tools not available."

fi

#
# Optional RTP peer
#

section "6. Media Peer Route"

if [ -n "$PEER_IP" ]; then

    echo "Requested media peer: $PEER_IP"
    echo

    if command_exists ip; then

        PEER_ROUTE="$(ip route get "$PEER_IP" 2>/dev/null || true)"

        if [ -n "$PEER_ROUTE" ]; then

            pass "Kernel route to media peer found."

            echo
            echo "$PEER_ROUTE"

            SOURCE_IP="$(
                printf '%s\n' "$PEER_ROUTE" |
                sed -n 's/.* src \([^ ]*\).*/\1/p' |
                head -1
            )"

            INTERFACE="$(
                printf '%s\n' "$PEER_ROUTE" |
                sed -n 's/.* dev \([^ ]*\).*/\1/p' |
                head -1
            )"

            echo

            if [ -n "$SOURCE_IP" ]; then
                echo "Selected source IP : $SOURCE_IP"
            fi

            if [ -n "$INTERFACE" ]; then
                echo "Selected interface : $INTERFACE"
            fi

        else

            warn "No route to $PEER_IP could be determined."

        fi

    fi

    echo

    if command_exists ping; then

        if ping -c 2 -W 2 "$PEER_IP" >/dev/null 2>&1; then
            pass "Peer responds to ICMP."
        else
            info "Peer did not answer ICMP. This does not prove RTP is unavailable."
        fi

    fi

else

    info "No media peer supplied."
    echo
    echo "Example:"
    echo
    echo "  sudo $0 --peer 203.0.113.10"

fi

#
# UDP socket state
#

section "7. Current UDP Socket State"

echo "RTP sockets are normally allocated dynamically during active calls."
echo "An idle server is therefore not expected to listen permanently on"
echo "every port in the configured RTP range."
echo

if command_exists ss; then

    if [ -n "$RTP_START" ] && [ -n "$RTP_END" ]; then

        ACTIVE_RTP="$(
            ss -uanp 2>/dev/null |
            awk -v start="$RTP_START" -v end="$RTP_END" '
            {
                split($5, a, ":")
                port=a[length(a)]

                if (port ~ /^[0-9]+$/ && port >= start && port <= end)
                    print
            }'
        )"

        if [ -n "$ACTIVE_RTP" ]; then

            info "UDP sockets currently detected inside the configured RTP range:"
            echo
            printf '%s\n' "$ACTIVE_RTP"

        else

            info "No current UDP sockets detected in the RTP range."
            info "This is normal when there are no active media sessions."

        fi

    else

        ss -uanp 2>/dev/null | head -30

    fi

elif command_exists netstat; then

    netstat -uanp 2>/dev/null | head -30

else

    warn "Neither ss nor netstat is available."

fi

#
# Active Asterisk channels
#

section "8. Active Asterisk Channels"

if [ -n "$ASTERISK_BIN" ]; then

    CHANNELS="$(
        "$ASTERISK_BIN" -rx "core show channels" 2>/dev/null || true
    )"

    if [ -n "$CHANNELS" ]; then
        echo "$CHANNELS"
    else
        info "No Asterisk channel information returned."
    fi

fi

#
# Firewall
#

section "9. Firewall Review"

echo "The configured RTP range must be permitted where appropriate."
echo

if command_exists firewall-cmd; then

    info "firewalld detected."

    firewall-cmd --list-ports 2>/dev/null || true

elif command_exists nft; then

    info "nftables detected."

    if [ -n "$RTP_START" ] && [ -n "$RTP_END" ]; then

        nft list ruleset 2>/dev/null |
            grep -Ei \
            "udp|${RTP_START}|${RTP_END}" |
            head -40 || true

    else

        nft list ruleset 2>/dev/null |
            grep -Ei 'udp' |
            head -40 || true

    fi

elif command_exists iptables; then

    info "iptables detected."

    iptables -L -n -v 2>/dev/null |
        grep -Ei 'udp|ACCEPT|DROP|REJECT' |
        head -50 || true

else

    info "No supported firewall-management utility detected."

fi

echo
echo "NOTE:"
echo "Firewall output requires manual interpretation."
echo "This script does not assume that a matching rule proves"
echo "end-to-end RTP reachability."

#
# SIP configuration media controls
#

section "10. Asterisk Media-Path Settings"

if [ -d /etc/asterisk ]; then

    echo "Relevant configured values found in Asterisk files:"
    echo

    grep -RniE \
        '^[[:space:]]*(directmedia|canreinvite|nat|rtp_symmetric|rewrite_contact|force_rport|external_media_address|local_net)[[:space:]]*=' \
        /etc/asterisk/*.conf 2>/dev/null |
        head -80 || true

else

    info "/etc/asterisk was not found."

fi

#
# SDP / NAT reminders
#

section "11. RTP Troubleshooting Checks"

cat <<'EOF'
When SIP signalling works but audio does not, check:

1. SDP connection address (c=)
2. SDP media port (m=audio)
3. Source and destination RTP addresses
4. NAT translation
5. Firewall UDP rules
6. Linux routing
7. Asymmetric routing
8. Provider media ACL
9. Codec negotiation
10. Direct-media configuration

Typical symptom:

SIP signalling:
Caller ---- Asterisk ---- Provider
                OK

Media:
Caller ===== RTP =====> Provider
Caller <==== RTP ====== Provider

A call can establish successfully while one or both RTP
directions are broken.
EOF

#
# Packet capture examples
#

section "12. RTP Capture Examples"

if [ -n "$RTP_START" ] && [ -n "$RTP_END" ]; then

    echo "Observe RTP-range UDP traffic:"
    echo
    echo "  tcpdump -nn -i any udp portrange $RTP_START-$RTP_END"

    echo
    echo "Capture to PCAP:"
    echo
    echo "  tcpdump -nn -i any -s 0 \\"
    echo "    udp portrange $RTP_START-$RTP_END \\"
    echo "    -w rtp-trace.pcap"

    if [ -n "$PEER_IP" ]; then

        echo
        echo "Restrict observation to media peer:"
        echo
        echo "  tcpdump -nn -i any host $PEER_IP and \\"
        echo "    udp portrange $RTP_START-$RTP_END"

    fi

else

    echo "Example using a common RTP range:"
    echo
    echo "  tcpdump -nn -i any udp portrange 10000-20000"

fi

#
# Summary
#

section "13. Summary"

echo "Passed checks   : $PASS_COUNT"
echo "Warnings        : $WARN_COUNT"

echo

if [ -n "$RTP_START" ] && [ -n "$RTP_END" ]; then
    echo "RTP range       : $RTP_START-$RTP_END"
else
    echo "RTP range       : not determined"
fi

if [ -n "$PEER_IP" ]; then
    echo "Media peer      : $PEER_IP"
else
    echo "Media peer      : not specified"
fi

echo
echo "============================================================"
echo " RTP check completed"
echo "============================================================"
echo
echo "Important:"
echo "This utility can verify configuration and routing information,"
echo "but it cannot prove two-way RTP without observing an active"
echo "media session."
echo
