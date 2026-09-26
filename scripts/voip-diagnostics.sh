#!/usr/bin/env bash

# Asterisk SIP/RTP Toolkit
# VoIP Diagnostics
#
# Author: Mohammad Sorower Jahan
# Repository:
# https://github.com/Core-daemon/asterisk-sip-rtp-toolkit
#
# Read-only diagnostic utility for Asterisk/Linux VoIP servers.
# It does not modify configuration.

set -u

ASTERISK_BIN="$(command -v asterisk 2>/dev/null || true)"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

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

fail()
{
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '[FAIL] %s\n' "$1"
}

info()
{
    printf '[INFO] %s\n' "$1"
}

command_exists()
{
    command -v "$1" >/dev/null 2>&1
}

asterisk_cmd()
{
    if [ -n "$ASTERISK_BIN" ]; then
        "$ASTERISK_BIN" -rx "$1" 2>/dev/null
    fi
}

echo
echo "============================================================"
echo "              Asterisk VoIP Diagnostics"
echo "============================================================"
echo
echo "Host: $(hostname 2>/dev/null || echo unknown)"
echo "Date: $(date)"
echo

#
# 1. Asterisk process
#

section "1. Asterisk Process"

if pgrep -x asterisk >/dev/null 2>&1; then
    pass "Asterisk process is running."
else
    fail "Asterisk process was not detected."
fi

if [ -n "$ASTERISK_BIN" ]; then
    pass "Asterisk CLI binary found at $ASTERISK_BIN"
else
    fail "Asterisk binary was not found in PATH."
fi

#
# 2. CLI communication
#

section "2. Asterisk CLI"

if [ -n "$ASTERISK_BIN" ]; then

    VERSION="$(asterisk_cmd "core show version" | head -1)"

    if [ -n "$VERSION" ]; then
        pass "Asterisk CLI is responding."
        echo "$VERSION"
    else
        fail "Asterisk CLI did not respond."
    fi

fi

#
# 3. SIP stack
#

section "3. SIP Stack Detection"

CHAN_SIP=0
PJSIP=0

if [ -n "$ASTERISK_BIN" ]; then

    if asterisk_cmd "module show like chan_sip" | grep -q "chan_sip.so"; then
        CHAN_SIP=1
        pass "chan_sip detected."
    fi

    if asterisk_cmd "module show like res_pjsip" | grep -q "res_pjsip"; then
        PJSIP=1
        pass "PJSIP detected."
    fi

    if [ "$CHAN_SIP" -eq 0 ] && [ "$PJSIP" -eq 0 ]; then
        fail "No supported SIP channel driver was detected."
    fi

fi

#
# 4. chan_sip peers
#

section "4. chan_sip Peer Health"

if [ "$CHAN_SIP" -eq 1 ]; then

    SIP_PEERS="$(asterisk_cmd "sip show peers")"

    UNREACHABLE="$(printf '%s\n' "$SIP_PEERS" |
        grep -ci 'UNREACHABLE' || true)"

    UNKNOWN="$(printf '%s\n' "$SIP_PEERS" |
        grep -ci 'UNKNOWN' || true)"

    LAGGED="$(printf '%s\n' "$SIP_PEERS" |
        grep -ci 'LAGGED' || true)"

    if [ "$UNREACHABLE" -gt 0 ]; then
        warn "$UNREACHABLE chan_sip peer(s) reported UNREACHABLE."
    else
        pass "No chan_sip peers reported UNREACHABLE."
    fi

    if [ "$UNKNOWN" -gt 0 ]; then
        warn "$UNKNOWN chan_sip peer(s) reported UNKNOWN."
    fi

    if [ "$LAGGED" -gt 0 ]; then
        warn "$LAGGED chan_sip peer(s) reported LAGGED."
    fi

    echo
    printf '%s\n' "$SIP_PEERS" | tail -20

else
    info "chan_sip is not active."
fi

#
# 5. chan_sip registrations
#

section "5. chan_sip Registrations"

if [ "$CHAN_SIP" -eq 1 ]; then

    SIP_REGISTRY="$(asterisk_cmd "sip show registry")"

    if printf '%s\n' "$SIP_REGISTRY" |
        grep -qi 'Registered'; then
        pass "At least one chan_sip registration is registered."
    else
        info "No Registered chan_sip entry detected."
    fi

    if printf '%s\n' "$SIP_REGISTRY" |
        grep -Eqi 'Rejected|Timeout|Request Sent|Failed|No Authentication'; then
        warn "One or more chan_sip registrations may require attention."
    fi

    echo
    printf '%s\n' "$SIP_REGISTRY"

else
    info "chan_sip registration check skipped."
fi

#
# 6. PJSIP endpoints
#

section "6. PJSIP Endpoint Health"

if [ "$PJSIP" -eq 1 ]; then

    PJSIP_ENDPOINTS="$(asterisk_cmd "pjsip show endpoints")"

    UNAVAILABLE="$(printf '%s\n' "$PJSIP_ENDPOINTS" |
        grep -ci 'Unavailable' || true)"

    if [ "$UNAVAILABLE" -gt 0 ]; then
        warn "$UNAVAILABLE PJSIP endpoint line(s) contain Unavailable."
    else
        pass "No unavailable PJSIP endpoints detected in summary."
    fi

    echo
    printf '%s\n' "$PJSIP_ENDPOINTS" | tail -30

else
    info "PJSIP is not active."
fi

#
# 7. PJSIP registrations
#

section "7. PJSIP Registrations"

if [ "$PJSIP" -eq 1 ]; then

    PJSIP_REG="$(asterisk_cmd "pjsip show registrations")"

    if printf '%s\n' "$PJSIP_REG" |
        grep -qi 'Registered'; then
        pass "At least one PJSIP registration is registered."
    else
        info "No Registered PJSIP registration detected."
    fi

    if printf '%s\n' "$PJSIP_REG" |
        grep -Eqi 'Rejected|Unregistered|Failed'; then
        warn "One or more PJSIP registrations may require attention."
    fi

    echo
    printf '%s\n' "$PJSIP_REG"

else
    info "PJSIP registration check skipped."
fi

#
# 8. SIP listening ports
#

section "8. SIP Listening Ports"

PORT_OUTPUT=""

if command_exists ss; then
    PORT_OUTPUT="$(ss -lunp 2>/dev/null || true)"
elif command_exists netstat; then
    PORT_OUTPUT="$(netstat -lunp 2>/dev/null || true)"
fi

if [ -n "$PORT_OUTPUT" ]; then

    if printf '%s\n' "$PORT_OUTPUT" | grep -q ':5060'; then
        pass "UDP/5060 listening socket detected."
    else
        warn "UDP/5060 was not detected."
    fi

    if printf '%s\n' "$PORT_OUTPUT" | grep -q ':5061'; then
        info "Port 5061 detected."
    fi

    if printf '%s\n' "$PORT_OUTPUT" | grep -q ':4569'; then
        info "IAX2 port 4569 detected."
    fi

else
    warn "Could not inspect listening UDP sockets."
fi

#
# 9. RTP configuration
#

section "9. RTP Configuration"

RTP_FILE="/etc/asterisk/rtp.conf"

if [ -r "$RTP_FILE" ]; then

    RTP_START="$(grep -Ei '^[[:space:]]*rtpstart[[:space:]]*=' "$RTP_FILE" |
        tail -1 |
        cut -d= -f2 |
        tr -d '[:space:]')"

    RTP_END="$(grep -Ei '^[[:space:]]*rtpend[[:space:]]*=' "$RTP_FILE" |
        tail -1 |
        cut -d= -f2 |
        tr -d '[:space:]')"

    if [ -n "$RTP_START" ] && [ -n "$RTP_END" ]; then
        pass "RTP range detected: $RTP_START-$RTP_END"
    else
        warn "Could not identify both rtpstart and rtpend."
    fi

else
    warn "$RTP_FILE is not readable."
fi

#
# 10. Network interfaces
#

section "10. Network Interfaces"

INTERFACE_COUNT=0

if command_exists ip; then

    INTERFACE_COUNT="$(
        ip -o link show 2>/dev/null |
        grep -v ' lo:' |
        wc -l
    )"

    echo "Non-loopback interfaces: $INTERFACE_COUNT"

    ip -brief addr 2>/dev/null || true

    if [ "$INTERFACE_COUNT" -gt 1 ]; then
        info "Multi-interface server detected."
        info "Check source-address and routing behaviour carefully."
    fi

else
    warn "'ip' command not available."
fi

#
# 11. Default route
#

section "11. Default Route"

if command_exists ip; then

    DEFAULT_ROUTE="$(ip route show default 2>/dev/null || true)"

    if [ -n "$DEFAULT_ROUTE" ]; then
        pass "Default route detected."
        echo "$DEFAULT_ROUTE"
    else
        warn "No default IPv4 route was detected."
    fi

fi

#
# 12. Routing table
#

section "12. Routing Table"

if command_exists ip; then

    ip route show 2>/dev/null

    ROUTE_COUNT="$(ip route show 2>/dev/null | wc -l)"

    if [ "$ROUTE_COUNT" -gt 1 ]; then
        pass "IPv4 routing table contains routes."
    else
        warn "Routing table appears very small."
    fi

elif command_exists route; then

    route -n 2>/dev/null

fi

#
# 13. IP forwarding
#

section "13. IP Forwarding"

if [ -r /proc/sys/net/ipv4/ip_forward ]; then

    IP_FORWARD="$(cat /proc/sys/net/ipv4/ip_forward)"

    if [ "$IP_FORWARD" = "1" ]; then
        info "IPv4 forwarding is enabled."
    else
        info "IPv4 forwarding is disabled."
    fi

fi

#
# 14. DNS test
#

section "14. DNS"

if command_exists getent; then

    if getent hosts example.com >/dev/null 2>&1; then
        pass "DNS resolution is working."
    else
        warn "DNS resolution test failed."
    fi

else
    info "getent not installed."
fi

#
# 15. Internet route selection
#

section "15. Route Selection"

if command_exists ip; then

    TEST_ROUTE="$(ip route get 1.1.1.1 2>/dev/null || true)"

    if [ -n "$TEST_ROUTE" ]; then
        pass "Kernel returned a route for external IPv4 traffic."
        echo "$TEST_ROUTE"
    else
        warn "No route returned for 1.1.1.1."
    fi

fi

#
# 16. Firewall
#

section "16. Firewall Detection"

if command_exists firewall-cmd; then

    info "firewalld detected."

    if firewall-cmd --state >/dev/null 2>&1; then
        pass "firewalld is running."
    fi

elif command_exists nft; then

    info "nftables detected."

elif command_exists iptables; then

    info "iptables detected."

else

    info "No supported firewall management command detected."

fi

#
# 17. Recent Asterisk errors
#

section "17. Recent Asterisk Errors"

LOG=""

for file in \
    /var/log/asterisk/full \
    /var/log/asterisk/messages \
    /var/log/asterisk/messages.log
do
    if [ -r "$file" ]; then
        LOG="$file"
        break
    fi
done

if [ -n "$LOG" ]; then

    echo "Log source: $LOG"
    echo

    RECENT_ERRORS="$(
        grep -Ei 'ERROR|WARNING|NOTICE|CRITICAL' "$LOG" 2>/dev/null |
        tail -20
    )"

    if [ -n "$RECENT_ERRORS" ]; then
        warn "Recent Asterisk warnings/errors were found."
        echo
        printf '%s\n' "$RECENT_ERRORS"
    else
        pass "No recent matching Asterisk errors found."
    fi

else
    info "No readable standard Asterisk log file found."
fi

#
# 18. Common NAT indicators
#

section "18. NAT Indicators"

PRIVATE_IPS=""

if command_exists ip; then

    PRIVATE_IPS="$(
        ip -4 -o addr show 2>/dev/null |
        awk '{print $4}' |
        cut -d/ -f1 |
        grep -E \
        '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)' || true
    )"

fi

if [ -n "$PRIVATE_IPS" ]; then

    info "Private IPv4 address(es) detected:"
    printf '%s\n' "$PRIVATE_IPS"

    info "If external SIP/RTP is used, verify NAT and SDP configuration."

else
    info "No RFC1918 IPv4 address detected."
fi

#
# 19. Active calls
#

section "19. Active Call State"

if [ -n "$ASTERISK_BIN" ]; then

    CHANNEL_OUTPUT="$(asterisk_cmd "core show channels")"

    if [ -n "$CHANNEL_OUTPUT" ]; then
        pass "Channel information retrieved."
        echo "$CHANNEL_OUTPUT"
    else
        warn "Unable to obtain channel information."
    fi

fi

#
# 20. Resource check
#

section "20. Server Resources"

if command_exists free; then

    free -h

fi

echo

if command_exists uptime; then
    uptime
fi

echo

df -h / 2>/dev/null || true

#
# Final diagnosis
#

section "Diagnostic Summary"

echo "PASS checks : $PASS_COUNT"
echo "WARN checks : $WARN_COUNT"
echo "FAIL checks : $FAIL_COUNT"
echo

if [ "$FAIL_COUNT" -gt 0 ]; then

    echo "Overall status: ATTENTION REQUIRED"

elif [ "$WARN_COUNT" -gt 0 ]; then

    echo "Overall status: REVIEW WARNINGS"

else

    echo "Overall status: BASIC CHECKS PASSED"

fi

echo
echo "============================================================"
echo " Diagnostics completed."
echo "============================================================"
echo
echo "Important:"
echo "A successful basic check does not guarantee correct SIP or RTP flow."
echo "Packet capture and SIP/SDP analysis may still be required."
echo
echo "This utility performs read-only diagnostic checks."
echo
