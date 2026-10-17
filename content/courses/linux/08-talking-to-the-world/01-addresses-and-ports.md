---
kind: lesson
id_key: linux/talking-to-the-world/addresses-and-ports
course: linux
section: talking-to-the-world
section_title: "Chapter 8: Talking to the World - Networking"
section_position: 8
title: "IP Addresses, Subnets and Ports"
position: 0
estimated_minutes: 7
source:
  - ip(7), tcp(7), udp(7) manual pages; RFC 1918 (private address space); IANA service name and port registry
---

## Why this matters

> **Tuesday, week 2.** The payment provider emails: *we can't reach your
> server*. Rhea: "Before you blame them, prove atlas is listening. Every service
> has an address and a door number."

Every network problem is described in addresses and ports. Without these words
you cannot even read the error message.

## Mental model: street address and door number

```
   IP address = the building           port = the door
   10.0.0.42                            :443  (HTTPS)

   client 203.0.113.5:51522  ------>  atlas 10.0.0.42:443  (nginx)
          (random high port)                (well-known port)
```

- An **IP address** identifies a network interface (a machine's connection).
- A **port** (0-65535) identifies one service on that machine.
- A **connection** is the pair of both ends: client IP:port to server IP:port.
- **TCP** is a reliable conversation (web, SSH, databases). **UDP** is send and
  forget (DNS lookups, video, metrics).

> **Memory hook:** the IP is the **street address of the café**, the port is
> **which door**: front door 80 for walk-ins, the locked side door 22 for staff.

## Special addresses

| Address | Meaning |
|---|---|
| `127.0.0.1` / `::1` | **localhost**: this machine; traffic never leaves it |
| `10.x.x.x`, `172.16-31.x.x`, `192.168.x.x` | private networks (offices, clouds, home) |
| `0.0.0.0` (in "listening on") | every interface on this machine |
| `169.254.x.x` | link-local: no DHCP answer was received |
| `2001:db8::/32`, `fe80::/10` | IPv6 documentation / link-local |

Private addresses are not reachable from the internet directly; a router or load
balancer translates (NAT) or forwards.

## Subnets in one picture

`10.0.0.0/24` is **CIDR** notation: the first 24 bits name the network, the rest
name hosts.

```
 10.0.0.0/24   network bits: 10.0.0     hosts: .0 - .255    256 addresses
 10.0.0.0/16   network bits: 10.0       hosts: 0.0 - 255.255  65,536 addresses
 10.0.0.42/32  exactly one address
```

Machines in the same subnet talk directly. To reach anything else they send
packets to the **default gateway** (the router).

## Well-known ports

| Port | Service | Port | Service |
|---|---|---|---|
| 22 | SSH | 443 | HTTPS |
| 25 | SMTP (mail) | 3306 | MySQL |
| 53 | DNS | 5432 | PostgreSQL |
| 80 | HTTP | 6379 | Redis |
| 123 | NTP (time) | 8080 | common app port |

`/etc/services` maps names to numbers on every machine.

Ports below 1024 are **privileged**: only root (or a process with the
`CAP_NET_BIND_SERVICE` capability) can listen on them. That is why apps often
listen on 8080 behind nginx on 80/443.

## See it work

```bash
grep -wE '^(ssh|https|postgresql)' /etc/services
```

What this does: looks up three service names. Expected output:

```
ssh		22/tcp				# SSH Remote Login Protocol
https		443/tcp				# http protocol over TLS/SSL
https		443/udp				# HTTP/3
postgresql	5432/tcp	postgres	# PostgreSQL Database
```

## Try it

Brewbot listens on `127.0.0.1:8080`. Can the payment provider at
`203.0.113.5` connect to it directly? And how many addresses does
`192.168.1.0/24` contain?

<details>
<summary>Show answer</summary>

No. `127.0.0.1` is localhost; only programs on atlas itself can connect. A
`/24` holds 256 addresses (usually 254 usable hosts).

</details>

## Common mistakes

- **Thinking `127.0.0.1` means "my server's address".** It means "whatever
  machine you are on". On your laptop, it is your laptop.
- **Binding an app to `127.0.0.1` and expecting outside access.** Bind
  `0.0.0.0` (or the specific interface), or put a proxy in front.
- **Running an app as root just to use port 80.** Use a reverse proxy or a
  capability instead.

## Remember

- IP = which machine, port = which service; TCP reliable, UDP send-and-forget.
- localhost `127.0.0.1`; listen `0.0.0.0` = all interfaces.
- `/24` = 256 addresses; other subnets go through the default gateway.
- 22 SSH, 53 DNS, 80 HTTP, 443 HTTPS, 5432 PostgreSQL; below 1024 = privileged.

**Self-check:**

1. What does listening on `0.0.0.0:8080` mean?
2. Which ranges are private IPv4 networks?
3. Why do apps often use port 8080 instead of 80?
