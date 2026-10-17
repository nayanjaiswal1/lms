---
kind: lesson
id_key: linux/talking-to-the-world/inspecting-the-network
course: linux
section: talking-to-the-world
section_title: "Chapter 8: Talking to the World - Networking"
section_position: 8
title: "Inspecting the Network: ip, ss, ping and traceroute"
position: 1
estimated_minutes: 8
source:
  - ip(8), ip-address(8), ip-route(8), ss(8), ping(8), tracepath(8), mtr(8) manual pages
---

## Why this matters

"Is atlas even on the network? Is brewbot listening? On which address? Can we
reach the gateway?" Four commands answer these in under a minute, and `ss` is
the single most useful networking command on a server.

## Mental model: check the building from the inside out

```
 1. Do I have an address?        ip a
 2. Do I know the way out?       ip r
 3. What is listening here?      ss -tulpn
 4. Can I reach the other side?  ping / traceroute / curl
```

Work in that order. Each step assumes the previous one is fine.

## See it work

### Interfaces and addresses

```bash
ip a            # short for: ip address show
```

Expected output (abridged):

```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 ...
    inet 127.0.0.1/8 scope host lo
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 ...
    inet 10.0.0.42/24 brd 10.0.0.255 scope global eth0
```

`lo` is loopback (localhost). `eth0` is the real interface with
`10.0.0.42` in a `/24`. `UP` means the link is active. (`ifconfig` is the old,
deprecated tool for the same thing.)

### Routes

```bash
ip r            # ip route show
```

```
default via 10.0.0.1 dev eth0
10.0.0.0/24 dev eth0 proto kernel scope link src 10.0.0.42
```

`default via 10.0.0.1` is the **gateway**: everything not in `10.0.0.0/24` goes
there. No default route = no internet.

### What is listening: ss

```bash
ss -tulpn
```

```
Netid State  Local Address:Port  Peer Address:Port Process
tcp   LISTEN 0.0.0.0:22          0.0.0.0:*         users:(("sshd",pid=812,fd=3))
tcp   LISTEN 127.0.0.1:8080      0.0.0.0:*         users:(("brewbot",pid=1040,fd=6))
tcp   LISTEN 0.0.0.0:443         0.0.0.0:*         users:(("nginx",pid=901,fd=7))
```

Flags: `t` TCP, `u` UDP, `l` listening only, `p` owning process (needs root to
see other users' processes), `n` numeric (no name lookups).

Note `127.0.0.1:8080`: brewbot only listens on localhost, so nobody outside can
reach it directly. That is fine behind nginx, but it is also the number one
reason for "the app runs but I can't connect".

```bash
ss -tn                       # current TCP connections
ss -tn state established '( dport = :5432 )'   # connections to PostgreSQL
ss -s                        # summary counts
```

(`netstat -tulpn` is the old equivalent.)

### Reachability

```bash
ping -c 3 10.0.0.1           # is the host answering? (ICMP, may be blocked)
tracepath example.com        # every hop on the way (or traceroute, mtr)
mtr -rwc 10 example.com      # ping + traceroute report: where does loss start?
```

A failed `ping` does not prove a host is down: many firewalls drop ICMP. Test
the real port with `curl` or `nc` (lessons 3 and 7).

```bash
hostname -I                  # this machine's IP addresses, one line
ip -br a                     # brief: one line per interface
```

## Try it

On atlas, the payment provider cannot connect to brewbot on port 8080. Which
command shows whether brewbot listens, and on which address? What in the output
would explain the problem?

<details>
<summary>Show answer</summary>

```bash
ss -tulpn | grep 8080
```

If the local address is `127.0.0.1:8080`, brewbot only accepts connections from
atlas itself. It needs to listen on `0.0.0.0:8080` (or be reached through nginx).

</details>

## Common mistakes

- **Trusting ping.** ICMP is often blocked. Test the actual TCP port.
- **`ss -tulpn` without root.** Other users' process names are hidden; use
  `sudo`.
- **Forgetting `-n`.** Without it, ss resolves names and ports, which can be slow
  and hides the numbers you need.

## Remember

- Inside out: `ip a`, `ip r`, `ss -tulpn`, then ping/traceroute/curl.
- `default via X` is the gateway.
- `ss -tulpn`: who listens on which address and port.
- `127.0.0.1:PORT` = local only; `0.0.0.0:PORT` = all interfaces.

**Self-check:**

1. Which command shows the default gateway?
2. What do the letters in `ss -tulpn` stand for?
3. Why is a failed ping not proof that a server is down?
