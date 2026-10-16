---
kind: lesson
id_key: linux/talking-to-the-world/firewalls
course: linux
section: talking-to-the-world
section_title: "Chapter 8: Talking to the World - Networking"
section_position: 8
title: "Firewalls: ufw, firewalld and nftables"
position: 5
estimated_minutes: 7
source:
  - ufw(8), firewall-cmd(1), nft(8), iptables(8) manual pages
---

## Why this matters

A firewall decides which packets may reach which port. Too open, and your
database is on the internet. Too closed, and the payment provider times out. And
one wrong rule over SSH can lock you out of your own server.

## Mental model: the bouncer at each door

```
 internet --> [ cloud security group ] --> [ host firewall (nftables) ] --> service
                 outside the machine            inside the kernel
```

- The kernel's packet filter is **netfilter**. You configure it with
  **nftables** (`nft`), the modern replacement for **iptables**.
- Friendly front ends write those rules for you: **ufw** on Ubuntu,
  **firewalld** (`firewall-cmd`) on RHEL/Fedora.
- In the cloud there is often a second firewall outside the machine (security
  groups). Both must allow the traffic.

Default policy for a server: **deny incoming, allow outgoing**, then open only
what you serve.

## See it work

These need root (not available in the lab).

```bash
sudo ufw status verbose
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp            # ALWAYS allow SSH before enabling!
sudo ufw allow 443/tcp
sudo ufw allow from 10.0.0.0/24 to any port 5432 proto tcp   # DB only from the office
sudo ufw enable
sudo ufw status numbered
sudo ufw delete 3                # remove rule number 3
```

Expected output of `ufw status`:

```
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
443/tcp                    ALLOW       Anywhere
5432/tcp                   ALLOW       10.0.0.0/24
```

### firewalld (RHEL family)

```bash
sudo firewall-cmd --list-all
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=10.0.0.0/24 port port=5432 protocol=tcp accept'
sudo firewall-cmd --reload
```

`--permanent` writes the config; `--reload` applies it. Without `--permanent`,
the rule is lost at the next reload or reboot.

### Looking underneath

```bash
sudo nft list ruleset            # what the kernel actually enforces
sudo iptables -L -n -v           # legacy view (often backed by nftables now)
```

### Reading the symptoms

> **Memory hook:** **refused = nobody home** (you reached the machine, but
> nothing listens on that port). **timed out = the gate is locked** (a firewall
> silently dropped the packets, or routing is broken).

| Error | Usual cause |
|---|---|
| `Connection refused` | service down, wrong port, or bound to 127.0.0.1 |
| `Connection timed out` | firewall / security group drop, or no route |
| `No route to host` | host down or a firewall actively rejecting |

## Try it

You are about to enable ufw on atlas over SSH. Which rule must exist first, and
how do you then let only the office network (`10.0.0.0/24`) reach PostgreSQL?

<details>
<summary>Show answer</summary>

```bash
sudo ufw allow 22/tcp
sudo ufw allow from 10.0.0.0/24 to any port 5432 proto tcp
sudo ufw enable
```

Without the SSH rule, enabling ufw cuts your own session.

</details>

## Common mistakes

- **Enabling the firewall before allowing SSH.** Instant lockout; you need the
  cloud console to recover.
- **Opening the database to `Anywhere`.** Limit by source network.
- **Fixing only the host firewall.** The cloud security group must allow it too.
- **firewalld rules without `--permanent`.** Gone after reload.

## Remember

- Default deny incoming, allow outgoing; open only what you serve.
- ufw: `allow 22/tcp` first, then `enable`; `status numbered`, `delete N`.
- firewalld: `--permanent` + `--reload`; nftables underneath (`nft list ruleset`).
- Refused = nothing listening; timed out = something dropping.

**Self-check:**

1. What is the difference between "connection refused" and "timed out"?
2. Why allow port 22 before `ufw enable`?
3. What does `--permanent` do in firewalld?
