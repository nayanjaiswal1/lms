---
kind: lesson
id_key: linux/talking-to-the-world/dns
course: linux
section: talking-to-the-world
section_title: "Chapter 8: Talking to the World - Networking"
section_position: 8
title: "DNS: Turning Names into Addresses"
position: 3
estimated_minutes: 7
source:
  - dig(1), getent(1), hosts(5), resolv.conf(5), nsswitch.conf(5), resolvectl(1) manual pages
---

## Why this matters

`curl https://api.payments.example` fails, but `curl https://203.0.113.10`
works. The network is fine; the name lookup is broken. "It's always DNS" is a
sysadmin joke because it is so often true.

## Mental model: the phone book chain

Programs ask the system to resolve a name. The system checks, in order:

```
 program --> /etc/nsswitch.conf ("hosts: files dns")
               |
               |-- 1. files: /etc/hosts        local overrides, checked FIRST
               |-- 2. dns:   the resolver in /etc/resolv.conf
                                 (on Ubuntu: systemd-resolved at 127.0.0.53)
                                     |
                                     v
                             DNS servers --> answer: 203.0.113.10 (cached for TTL seconds)
```

Record types you will meet:

| Type | Maps | Example |
|---|---|---|
| `A` / `AAAA` | name to IPv4 / IPv6 | `orbit.coffee -> 203.0.113.10` |
| `CNAME` | alias to another name | `www -> orbit.coffee` |
| `MX` | mail servers for a domain | `10 mail.orbit.coffee` |
| `TXT` | text (SPF, verification) | `"v=spf1 ..."` |
| `NS` | which servers are authoritative | `ns1.example.net` |

**TTL** (time to live) is how long an answer may be cached. After you change a
record, old answers live on until their TTL expires.

## See it work

```bash
getent hosts localhost
cat /etc/hosts
cat /etc/resolv.conf
```

What this does: resolves a name the way programs do (including `/etc/hosts`),
then shows the two config files. Expected output on Ubuntu (similar; inside a
container `resolv.conf` is written by the container runtime instead):

```
::1             localhost ip6-localhost ip6-loopback
127.0.0.1	localhost
::1	localhost ip6-localhost ip6-loopback
nameserver 127.0.0.53
options edns0 trust-ad
```

### Asking DNS directly

`dig` (package `dnsutils` / `bind-utils`) talks to DNS servers and shows the raw
answer:

```bash
dig orbit.coffee +short          # just the address
dig MX orbit.coffee +short       # mail servers
dig @1.1.1.1 orbit.coffee        # ask a specific server
dig +trace orbit.coffee          # follow the chain from the root servers
resolvectl status                # systemd-resolved: which DNS server per interface
```

`dig` bypasses `/etc/hosts`; `getent hosts` does not. When they disagree, a
stale `/etc/hosts` line is the usual reason.

### /etc/hosts: local overrides

```
127.0.0.1   localhost
10.0.0.42   atlas atlas.internal
```

Pin a name to an IP on one machine, for example to test a new server before
switching DNS. Remove the line afterwards: forgotten entries cause confusing
outages months later.

> **Memory hook:** "**It's always DNS.**" When a name fails but the IP works,
> the problem is name resolution, not the network.

## Try it

`curl https://api.payments.example` fails with "Could not resolve host", but the
IP works. List three things you check, in order.

<details>
<summary>Show answer</summary>

1. `getent hosts api.payments.example` and `grep payments /etc/hosts`: is there a
   stale local override?
2. `cat /etc/resolv.conf` / `resolvectl status`: which DNS server is used, and is
   it reachable?
3. `dig api.payments.example` and `dig @1.1.1.1 api.payments.example`: does
   another resolver answer? If yes, your resolver is the problem.

</details>

## Common mistakes

- **Testing with `ping` or `dig` only.** `dig` ignores `/etc/hosts`; use
  `getent hosts` to see what programs see.
- **Changing a record and expecting instant effect.** Old answers stay cached
  until the TTL expires. Lower the TTL a day before a migration.
- **Editing `/etc/resolv.conf` by hand on Ubuntu.** It is managed by
  systemd-resolved; configure netplan or `resolved.conf` instead.

## Remember

- Lookup order: `/etc/hosts`, then DNS from `/etc/resolv.conf`.
- `getent hosts NAME` = what programs see; `dig NAME` = what DNS says.
- A/AAAA address, CNAME alias, MX mail, TXT text; TTL = cache time.
- Name fails but IP works: it's DNS.

**Self-check:**

1. Which file is checked before DNS?
2. Why can `dig` and `getent` give different answers?
3. What is a TTL?
