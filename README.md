# Asterisk SIP/RTP Toolkit

Practical Asterisk SIP/RTP diagnostics, configuration examples and Linux troubleshooting tools for VoIP engineers.

**Author:** Mohammad Sorower Jahan  
**Engineering Area:** VoIP, SIP, RTP, Asterisk, Linux and Telecommunications Infrastructure

---

## Overview

This repository is a practical engineering toolkit for people working with Asterisk-based VoIP infrastructure.

It focuses on the areas that usually need to be checked when diagnosing SIP and RTP problems:

- Asterisk service status
- SIP and PJSIP registrations
- trunk and endpoint reachability
- RTP configuration
- NAT behaviour
- Linux network interfaces
- routing
- firewall connectivity
- codec negotiation
- one-way audio
- no-audio problems
- active channels and calls
- basic server resource utilisation

The aim is to bring Asterisk and Linux-side troubleshooting into one practical repository instead of treating SIP, RTP and network diagnostics as separate subjects.

---

## Why I Created This Toolkit

In VoIP troubleshooting, the problem is often not located in one place.

A failed or unstable call can involve several different layers:

```text
Application
    |
    v
Asterisk
    |
    v
SIP Signalling
    |
    v
SDP Negotiation
    |
    v
RTP Media
    |
    v
Linux Networking
    |
    v
Routing / NAT / Firewall
    |
    v
SIP Provider / SBC
```

For example, an Asterisk trunk can appear correctly configured while the actual problem is:

- an incorrect route;
- an unreachable RTP address;
- NAT rewriting;
- firewall restrictions;
- codec incompatibility;
- SIP registration failure;
- incorrect SDP information;
- a provider-side connectivity problem.

This project is intended to provide practical checks for these situations.

---

# Core Areas

## SIP Diagnostics

The SIP troubleshooting section focuses on:

- registration status
- endpoint status
- peer reachability
- SIP OPTIONS responses
- authentication problems
- trunk configuration
- provider connectivity
- SIP listening ports
- chan_sip diagnostics
- PJSIP diagnostics

---

## RTP Diagnostics

The RTP section focuses on:

- configured RTP port range
- RTP reachability
- one-way audio
- no audio
- NAT-related media problems
- direct media
- media relay
- firewall restrictions
- RTP source and destination behaviour

---

## Linux Network Diagnostics

VoIP problems frequently originate below the Asterisk layer.

The Linux-side checks therefore include:

- IP addresses
- interfaces
- interface state
- routing tables
- default routes
- static routes
- gateway reachability
- DNS resolution
- listening ports
- UDP connectivity
- firewall state
- network latency

---

## Asterisk System Diagnostics

The toolkit is also intended to collect information about the running Asterisk environment.

Typical checks include:

- Asterisk service state
- Asterisk version
- loaded SIP modules
- active channels
- active calls
- registered trunks
- configured endpoints
- RTP settings
- recent warnings
- recent errors
- CPU utilisation
- memory utilisation
- disk utilisation

---

# Planned Toolkit Structure

The repository is being organised around the following structure:

```text
asterisk-sip-rtp-toolkit/
│
├── README.md
├── LICENSE
├── CONTRIBUTING.md
│
├── scripts/
│   ├── asterisk-health-check.sh
│   ├── sip-peer-check.sh
│   ├── rtp-port-check.sh
│   ├── network-route-check.sh
│   └── voip-diagnostics.sh
│
├── configs/
│   ├── chan-sip/
│   │   ├── sip-trunk-example.conf
│   │   └── nat-example.conf
│   │
│   ├── pjsip/
│   │   ├── pjsip-trunk-example.conf
│   │   └── endpoint-example.conf
│   │
│   └── dialplan/
│       └── extensions-example.conf
│
├── troubleshooting/
│   ├── sip-registration.md
│   ├── one-way-audio.md
│   ├── no-audio.md
│   ├── nat-troubleshooting.md
│   ├── codec-troubleshooting.md
│   └── trunk-unreachable.md
│
└── docs/
    ├── sip-call-flow.md
    ├── rtp-media-flow.md
    └── architecture.md
```

The structure will expand as additional tools and engineering examples are added.

---

# Asterisk Health Check

One of the main utilities planned for this repository is:

```text
scripts/asterisk-health-check.sh
```

The purpose of the script is to collect useful troubleshooting information from both Asterisk and the underlying Linux server.

Typical output will include:

```text
========================================
 Asterisk SIP/RTP Health Check
========================================

Asterisk service: RUNNING
Asterisk version: detected

SIP modules:
PJSIP: detected
chan_sip: detected/not detected

Channels:
Active channels: detected
Active calls: detected

RTP:
Configured port range: detected

Network:
Interfaces: detected
Default route: detected

System:
CPU utilisation: detected
Memory utilisation: detected
Disk utilisation: detected

Warnings:
Recent Asterisk warnings/errors displayed

========================================
```

The script is intended to help engineers collect a useful first-level diagnostic snapshot before carrying out deeper analysis.

---

# Example Troubleshooting Workflow

A practical VoIP troubleshooting sequence can be:

```text
1. Confirm Asterisk is running
                |
                v
2. Confirm SIP/PJSIP module
                |
                v
3. Check trunk registration
                |
                v
4. Check peer/endpoint reachability
                |
                v
5. Confirm Linux routing
                |
                v
6. Confirm SIP port connectivity
                |
                v
7. Check RTP configuration
                |
                v
8. Check NAT/firewall behaviour
                |
                v
9. Check codec negotiation
                |
                v
10. Inspect SIP/RTP traffic if required
```

The toolkit is designed around this layered approach.

---

# SIP Call Flow

A simplified SIP call can be represented as:

```text
Caller
   |
   | INVITE
   v
Asterisk
   |
   | INVITE
   v
SIP Provider / SBC
   |
   | 100 Trying
   | 180 Ringing
   | 200 OK
   v
Asterisk
   |
   | SIP response
   v
Caller
```

The actual signalling path depends on the network and trunk architecture.

---

# RTP Media Flow

SIP signalling and RTP media should be considered separately.

A common media-relay arrangement is:

```text
Caller
   |
   | RTP
   v
Asterisk
   |
   | RTP
   v
Provider
```

Where direct media is supported, the media relationship may instead be:

```text
Caller <============== RTP ==============> Provider
```

Troubleshooting should therefore identify both:

```text
SIP signalling path
```

and:

```text
RTP media path
```

rather than assuming that successful SIP signalling guarantees successful audio.

---

# One-Way Audio

One-way audio is one of the most common VoIP problems.

Example:

```text
Caller -------- RTP --------> Provider
Caller <------- X ----------- Provider
```

or:

```text
Caller -------- X ----------> Provider
Caller <------- RTP --------- Provider
```

Common causes include:

- NAT
- incorrect SDP address
- firewall rules
- missing routes
- provider media restrictions
- private IP addresses being advertised externally
- asymmetric routing

The troubleshooting section will contain practical checks for these conditions.

---

# SIP Registration Problems

A registration problem may involve:

```text
Asterisk
    |
    | REGISTER
    v
SIP Provider
```

Possible causes include:

- incorrect username
- incorrect password
- wrong registrar address
- DNS failure
- routing failure
- firewall restriction
- provider ACL
- NAT problems
- SIP transport mismatch
- incorrect port

The toolkit will provide checks that help distinguish between configuration and network problems.

---

# chan_sip and PJSIP

The repository is intended to cover both:

```text
chan_sip
```

and:

```text
PJSIP
```

where appropriate.

Older Asterisk environments may still use `chan_sip`, while newer installations commonly use PJSIP.

Configuration examples will therefore be kept in separate directories to avoid mixing the two configuration models.

---

# Example chan_sip Layout

A simplified example may look like:

```ini
[provider]
type=peer
host=sip.example.net
context=from-provider
disallow=all
allow=ulaw
qualify=yes
directmedia=no
```

This is an illustrative example only.

Real deployments require settings appropriate to the provider, network architecture and security requirements.

---

# Example PJSIP Layout

A simplified PJSIP structure may involve:

```ini
[provider]
type=endpoint
transport=transport-udp
context=from-provider
disallow=all
allow=ulaw
aors=provider
outbound_auth=provider-auth

[provider]
type=aor
contact=sip:sip.example.net

[provider-auth]
type=auth
auth_type=userpass
username=example-user
password=CHANGE_ME
```

These examples use placeholder information and must not be copied directly into production without review.

---

# Dialplan Examples

A basic outbound example might look like:

```ini
[outbound]
exten => _X.,1,NoOp(Outbound call to ${EXTEN})
 same => n,Dial(PJSIP/${EXTEN}@provider,60)
 same => n,Hangup()
```

The project will include practical dialplan examples where they are useful for demonstrating call routing behaviour.

---

# NAT Considerations

NAT is one of the main causes of SIP/RTP problems.

A common architecture is:

```text
Asterisk
Private IP
   |
   v
Router / NAT
   |
   v
Internet
   |
   v
SIP Provider
```

Troubleshooting may require checking:

- local IP
- public IP
- Contact header
- Via header
- SDP connection address
- RTP destination
- firewall state
- port forwarding
- symmetric RTP
- provider-side received address

The toolkit will document these separately rather than treating NAT as a single configuration setting.

---

# Multi-Homed Asterisk Servers

Some VoIP servers use more than one network interface.

Example:

```text
                   +---------------- Private Network
                   |
Asterisk ----------+
                   |
                   +---------------- Provider Network
```

In these environments, successful SIP communication may depend on:

- source IP selection
- static routes
- routing metrics
- provider-specific routes
- interface binding
- firewall rules

The Linux routing section will therefore be an important part of this toolkit.

---

# Useful Asterisk Commands

Examples of commonly used diagnostic commands include:

```bash
asterisk -rx "core show version"
```

```bash
asterisk -rx "core show channels"
```

For chan_sip:

```bash
asterisk -rx "sip show peers"
```

```bash
asterisk -rx "sip show registry"
```

For PJSIP:

```bash
asterisk -rx "pjsip show endpoints"
```

```bash
asterisk -rx "pjsip show registrations"
```

RTP configuration:

```bash
asterisk -rx "rtp show settings"
```

Loaded modules:

```bash
asterisk -rx "module show"
```

---

# Useful Linux Commands

Network interfaces:

```bash
ip addr show
```

Routing:

```bash
ip route show
```

Route selection:

```bash
ip route get 8.8.8.8
```

Listening UDP sockets:

```bash
ss -lunp
```

Listening TCP sockets:

```bash
ss -ltnp
```

Interface statistics:

```bash
ip -s link
```

DNS:

```bash
getent hosts example.com
```

These commands may also be incorporated into automated diagnostic scripts.

---

# Packet Analysis

For deeper troubleshooting, packet inspection may be required.

Useful tools include:

- `tcpdump`
- `sngrep`
- Wireshark
- `iftop`
- `ss`
- Asterisk SIP logging

Example SIP capture:

```bash
tcpdump -n -i any udp port 5060
```

Example RTP observation:

```bash
tcpdump -n -i any udp portrange 10000-20000
```

Actual RTP port ranges depend on the Asterisk configuration.

---

# Security

Never publish production:

- SIP passwords
- authentication secrets
- API keys
- customer telephone numbers
- private customer information
- provider credentials
- SSH keys
- database passwords
- private certificates

Examples in this repository should use values such as:

```text
example.com
192.0.2.0/24
198.51.100.0/24
203.0.113.0/24
CHANGE_ME
example-user
```

rather than real customer or provider credentials.

---

# Production Use

The scripts and configuration examples in this repository are intended for:

- engineering reference
- troubleshooting
- testing
- learning
- infrastructure diagnostics

They should be reviewed before being used on a production system.

Asterisk environments differ considerably depending on:

- version
- distribution
- provider
- firewall
- NAT
- network topology
- codec
- security requirements

There is therefore no single configuration that is suitable for every deployment.

---

# Compatibility

The toolkit is intended to support practical Asterisk environments across multiple Linux distributions.

Where a command or example depends on:

- Asterisk version
- chan_sip
- PJSIP
- Linux distribution
- package manager

the relevant limitation should be documented with that tool or example.

The project is not limited to Asterisk 16.

---

# Contributions

Contributions are welcome.

Useful contributions may include:

- additional SIP diagnostics
- PJSIP examples
- chan_sip examples
- NAT troubleshooting cases
- RTP troubleshooting methods
- IPv6 VoIP examples
- firewall examples
- documentation corrections
- testing on different Asterisk versions
- Linux distribution compatibility improvements
- bug reports
- feature requests

If you identify a problem or improvement, please open an issue.

Pull requests are also welcome.

---

# Reporting Problems

When reporting a problem, useful information may include:

```text
Asterisk version:
Linux distribution:
SIP stack: PJSIP / chan_sip
Problem:
Expected behaviour:
Actual behaviour:
Relevant error:
Network topology:
```

Do not include passwords or other sensitive credentials.

---

# Project Roadmap

Planned areas include:

- Asterisk health-check script
- SIP registration diagnostic script
- PJSIP endpoint diagnostics
- chan_sip peer diagnostics
- RTP configuration checker
- routing diagnostics
- NAT troubleshooting
- firewall checks
- codec diagnostics
- one-way audio troubleshooting
- SIP call-flow documentation
- RTP media-flow documentation
- multi-interface Asterisk diagnostics
- example SIP trunk configurations
- example dialplans

The roadmap will evolve based on testing and community feedback.

---

# Engineering Approach

The project follows a simple troubleshooting principle:

```text
Do not assume that an Asterisk problem
is automatically an Asterisk configuration problem.
```

VoIP troubleshooting should consider the complete path:

```text
Dialplan
   |
SIP
   |
SDP
   |
RTP
   |
Linux network
   |
Routing
   |
NAT
   |
Firewall
   |
Provider
```

Understanding the interaction between these layers is often more useful than changing individual configuration parameters without first identifying the actual failure point.

---

# Author

**Mohammad Sorower Jahan**

VoIP, Telecommunications Infrastructure and Linux Systems Engineer

Technical areas:

**VoIP | SIP | SDP | RTP | Asterisk | Linux | Proxmox | TCP/IP | Routing | NAT | Firewalls | Telecommunications Infrastructure**

Website:

**https://www.msjahan.com**

GitHub:

**https://github.com/Core-daemon**

---

## Disclaimer

This repository contains engineering examples and troubleshooting material.

Configuration examples use generic or documentation addresses and are not intended to disclose production credentials or customer infrastructure.

Always review security, routing, firewall and provider requirements before applying any configuration to a production VoIP system.
