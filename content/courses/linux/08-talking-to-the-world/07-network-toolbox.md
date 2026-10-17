---
kind: lesson
id_key: linux/talking-to-the-world/network-toolbox
course: linux
section: talking-to-the-world
section_title: "Chapter 8: Talking to the World - Networking"
section_position: 8
title: "The Network Debugging Toolbox: nc, tcpdump and openssl"
position: 6
estimated_minutes: 7
source:
  - nc(1), tcpdump(8), pcap-filter(7), openssl-s_client(1) manual pages
---

## Why this matters

Sometimes `curl` is not enough: the service is not HTTP, you need to know if
packets arrive at all, or the TLS certificate is the problem. Three tools cover
those cases, and a fallback works even on minimal images.

## Mental model: three levels of looking

```
 Can I open the door?          nc -vz host port         (TCP connect test)
 What crosses the wire?        tcpdump                  (watch the packets)
 Is the TLS lock right?        openssl s_client         (certificate, dates, chain)
```

## See it work

### nc (netcat): any TCP port

```bash
nc -vz 10.0.0.42 5432       # can I connect to PostgreSQL?
nc -vz -w 3 10.0.0.42 6379  # give up after 3 seconds
```

```
Connection to 10.0.0.42 5432 port [tcp/postgresql] succeeded!
```

If `nc` is missing, bash itself can test a port:

```bash
timeout 3 bash -c '</dev/tcp/127.0.0.1/8080' && echo open || echo closed
```

`/dev/tcp/HOST/PORT` is a bash feature: opening it makes a TCP connection.

`nc -l 9000` listens on a port, which helps prove a firewall rule works before
the real service exists.

### tcpdump: watch the packets

```bash
sudo tcpdump -ni eth0 port 443                 # all traffic on 443
sudo tcpdump -ni any host 203.0.113.5          # one remote host
sudo tcpdump -ni eth0 'tcp[tcpflags] & tcp-syn != 0' -c 20   # new connection attempts
sudo tcpdump -ni eth0 port 8080 -w cap.pcap    # save for Wireshark
```

`-n` = no name lookups, `-i` = interface (`any` for all), `-c` = stop after N
packets. The killer question it answers: **do the packets even arrive?** If SYN
packets arrive and nothing answers, the service or host firewall is the issue. If
nothing arrives, look upstream (security group, routing).

### openssl: inspect TLS

```bash
echo | openssl s_client -connect orbit.coffee:443 -servername orbit.coffee 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates
```

Expected output (similar):

```
subject=CN = orbit.coffee
issuer=C = US, O = Let's Encrypt, CN = R11
notBefore=Sep 20 00:00:00 2026 GMT
notAfter=Dec 19 23:59:59 2026 GMT
```

`notAfter` in the past = expired certificate. `-servername` sends SNI, needed
when one IP hosts many sites.

### Putting it together

```
 1. ss -tulpn on the server     is it listening, and where?
 2. curl / nc from the server   does it answer locally?
 3. nc from outside             does it answer remotely?
 4. tcpdump on the server       do packets arrive at all?
 5. openssl s_client            for TLS errors
```

## Try it

A Redis server at `10.0.0.50:6379` "does not work" from atlas. `nc` is not
installed. How do you check if the port is reachable?

<details>
<summary>Show answer</summary>

```bash
timeout 3 bash -c '</dev/tcp/10.0.0.50/6379' && echo open || echo closed
```

`open` means TCP connects (look at Redis auth/config next). `closed` quickly
means refused; `closed` after 3 seconds means timeout, so suspect a firewall.

</details>

## Common mistakes

- **tcpdump without `-n`.** It does DNS lookups for every packet, which is slow
  and adds its own traffic.
- **Capturing on the wrong interface.** Use `-i any` when unsure.
- **Forgetting `-servername`.** You may get the default certificate, not the
  site's.

## Remember

- `nc -vz host port` (or bash `/dev/tcp`) tests a TCP port.
- `tcpdump -ni IFACE port N` shows whether packets arrive.
- `openssl s_client ... | openssl x509 -noout -dates` checks certificates.
- Debug in layers: listen, local, remote, wire, TLS.

**Self-check:**

1. What does it mean if SYN packets arrive but nothing answers?
2. How do you test a port without `nc` or `curl`?
3. Which field shows when a certificate expires?
