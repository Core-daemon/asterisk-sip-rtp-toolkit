#!/usr/bin/env bash

# Asterisk SIP/RTP Toolkit
# Basic Asterisk and Linux VoIP health check
#
# Author: Mohammad Sorower Jahan
# Repository: https://github.com/Core-daemon/asterisk-sip-rtp-toolkit
#
# This script performs read-only diagnostic checks.
# It does not modify Asterisk or Linux configuration.

set -u

ASTERISK_BIN="$(command -v asterisk 2>/dev/null || true)"

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

ok()
{
    printf '[OK] %s\n' "$1"
}

warn()
{
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

echo
echo "============================================================"
echo "          Asterisk SIP/RTP Health Check"
echo "============================================================"
echo
echo "Host: $(hostname 2>/dev/null || echo unknown)"
echo "Date: $(date)"
echo

#
# Operating system
#

section "1. Operating System"

if [ -r /etc/os-release ]; then
    grep -E '^(PRETTY_NAME|NAME|VERSION)=' /etc/os-release 2>/dev/null
elif [ -r /etc/redhat-release ]; then
    cat /etc/redhat-release
else
    uname -a
fi

echo
uname -r 2>/dev/null | awk '{print "Kernel: " $0}'
uname -m 2>/dev/null | awk '{print "Architecture: " $0}'

#
# Asterisk installation
#

section "2. Asterisk Installation"

if [ -n "$ASTERISK_BIN" ]; then
    ok "Asterisk binary found: $ASTERISK_BIN"

    AST_VERSION="$("$ASTERISK_BIN" -rx "core show version" 2>/dev/null | head -1 || true)"

    if [ -n "$AST_VERSION" ]; then
        echo "$AST_VERSION"
    else
        warn "Asterisk CLI did not respond."
    fi
else
    warn "Asterisk binary was not found in PATH."
fi

#
# Service status
#

section "3. Asterisk Service"

if command_exists systemctl; then

    if systemctl is-active --quiet asterisk 2>/dev/null; then
        ok "Asterisk systemd service is running."
    else
        warn "Asterisk systemd service is not reported as active."
    fi

    systemctl status asterisk --no-pager 2>/dev/null | head -12 || true

elif command_exists service; then

    service asterisk status 2>/dev/null || true

else
    info "systemctl/service command not available."
fi

#
# Running process
#

section "4. Asterisk Process"

if pgrep -x asterisk >/dev/null 2>&1; then
    ok "Asterisk process detected."

    ps -eo pid,user,%cpu,%mem,etime,cmd 2>/dev/null |
        grep '[a]sterisk' |
        head -10
else
    warn "No Asterisk process detected."
fi

#
# SIP technology modules
#

section "5. SIP Modules"

if [ -n "$ASTERISK_BIN" ]; then

    CHAN_SIP="$("$ASTERISK_BIN" -rx "module show like chan_sip" 2>/dev/null || true)"

    if echo "$CHAN_SIP" | grep -q "chan_sip.so"; then
        ok "chan_sip is loaded."
    else
        info "chan_sip is not loaded."
    fi

    PJSIP="$("$ASTERISK_BIN" -rx "module show like res_pjsip" 2>/dev/null || true)"

    if echo "$PJSIP" | grep -q "res_pjsip"; then
        ok "PJSIP modules detected."
    else
        info "PJSIP modules were not detected."
    fi

fi

#
# chan_sip information
#

section "6. chan_sip Status"

if [ -n "$ASTERISK_BIN" ]; then

    if "$ASTERISK_BIN" -rx "sip show settings" >/dev/null 2>&1; then

        echo "SIP peers:"
        "$ASTERISK_BIN" -rx "sip show peers" 2>/dev/null | tail -15

        echo
        echo "SIP registrations:"
        "$ASTERISK_BIN" -rx "sip show registry" 2>/dev/null || true

    else
        info "chan_sip CLI commands are not available."
    fi

fi

#
# PJSIP information
#

section "7. PJSIP Status"

if [ -n "$ASTERISK_BIN" ]; then

    if "$ASTERISK_BIN" -rx "pjsip show endpoints" >/dev/null 2>&1; then

        echo "PJSIP endpoints:"
        "$ASTERISK_BIN" -rx "pjsip show endpoints" 2>/dev/null | tail -25

        echo
        echo "PJSIP registrations:"
        "$ASTERISK_BIN" -rx "pjsip show registrations" 2>/dev/null || true

    else
        info "PJSIP CLI commands are not available."
    fi

fi

#
# Channels and calls
#

section "8. Active Calls and Channels"

if [ -n "$ASTERISK_BIN" ]; then

    "$ASTERISK_BIN" -rx "core show channels" 2>/dev/null || \
        warn "Unable to obtain channel information."

fi

#
# RTP settings
#

section "9. RTP Configuration"

if [ -n "$ASTERISK_BIN" ]; then

    "$ASTERISK_BIN" -rx "rtp show settings" 2>/dev/null || \
        info "Asterisk RTP settings command unavailable."

fi

if [ -r /etc/asterisk/rtp.conf ]; then

    echo
    echo "Configured RTP values from /etc/asterisk/rtp.conf:"

    grep -Ei '^[[:space:]]*(rtpstart|rtpend|strictrtp|icesupport)[[:space:]]*=' \
        /etc/asterisk/rtp.conf 2>/dev/null || true

fi

#
# Network interfaces
#

section "10. Network Interfaces"

if command_exists ip; then

    ip -brief addr 2>/dev/null || ip addr show 2>/dev/null

elif command_exists ifconfig; then

    ifconfig -a 2>/dev/null

else
    warn "Neither ip nor ifconfig is available."
fi

#
# Routing
#

section "11. Routing Table"

if command_exists ip; then

    ip route show 2>/dev/null

elif command_exists route; then

    route -n 2>/dev/null

else
    warn "No routing-table command found."
fi

echo
echo "Default route:"

if command_exists ip; then
    ip route show default 2>/dev/null || true
fi

#
# Listening ports
#

section "12. SIP and Asterisk Listening Ports"

if command_exists ss; then

    ss -lntup 2>/dev/null |
        grep -Ei 'asterisk|:5060|:5061|:4569' || \
        info "No standard SIP/IAX listening ports detected in ss output."

elif command_exists netstat; then

    netstat -lntup 2>/dev/null |
        grep -Ei 'asterisk|:5060|:5061|:4569' || \
        info "No standard SIP/IAX listening ports detected."

else
    warn "Neither ss nor netstat is available."
fi

#
# Firewall
#

section "13. Firewall"

if command_exists firewall-cmd; then

    echo "firewalld:"
    firewall-cmd --state 2>/dev/null || true
    firewall-cmd --list-all 2>/dev/null || true

elif command_exists nft; then

    echo "nftables detected."
    nft list ruleset 2>/dev/null | head -60

elif command_exists iptables; then

    echo "iptables detected."
    iptables -L -n 2>/dev/null | head -60

else

    info "No supported firewall command detected."

fi

#
# System resources
#

section "14. System Resources"

echo "Load:"
uptime 2>/dev/null || true

echo
echo "Memory:"

if command_exists free; then
    free -h 2>/dev/null
else
    cat /proc/meminfo 2>/dev/null | head -10
fi

echo
echo "Disk:"
df -h / 2>/dev/null || true

#
# Recent Asterisk warnings/errors
#

section "15. Recent Asterisk Warnings and Errors"

LOG_FILE=""

for candidate in \
    /var/log/asterisk/full \
    /var/log/asterisk/messages \
    /var/log/asterisk/messages.log
do
    if [ -r "$candidate" ]; then
        LOG_FILE="$candidate"
        break
    fi
done

if [ -n "$LOG_FILE" ]; then

    echo "Source: $LOG_FILE"
    echo

    grep -Ei 'WARNING|ERROR|NOTICE|CRITICAL' "$LOG_FILE" 2>/dev/null |
        tail -20 || \
        info "No matching recent warnings/errors found."

else

    info "No readable standard Asterisk log file found."

fi

#
# Summary
#

section "16. Basic Summary"

if pgrep -x asterisk >/dev/null 2>&1; then
    echo "Asterisk process      : RUNNING"
else
    echo "Asterisk process      : NOT DETECTED"
fi

if [ -n "$ASTERISK_BIN" ]; then
    echo "Asterisk CLI         : AVAILABLE"
else
    echo "Asterisk CLI         : NOT FOUND"
fi

if command_exists ip; then
    echo "Linux IP tools       : AVAILABLE"
else
    echo "Linux IP tools       : NOT DETECTED"
fi

if command_exists ss || command_exists netstat; then
    echo "Socket diagnostics   : AVAILABLE"
else
    echo "Socket diagnostics   : NOT DETECTED"
fi

echo
echo "============================================================"
echo " Health check completed."
echo "============================================================"
echo
echo "This script performs read-only diagnostic checks."
echo "Review results in the context of your own VoIP environment."
echo
