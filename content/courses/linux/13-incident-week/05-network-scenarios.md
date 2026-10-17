---
kind: lesson
id_key: linux/incident-week/network-scenarios
course: linux
section: incident-week
section_title: "Chapter 13: Incident Week - Troubleshooting Playbook"
section_position: 13
title: "Network Scenarios: Can't Connect, DNS, SSH Refused, TLS and Clocks"
position: 4
estimated_minutes: 8
source:
  - ss(8), curl(1), dig(1), ssh(1), timedatectl(1), openssl-s_client(1) manual pages
---

## Why this matters

"It works on the server but customers can't reach it", "the API name doesn't
resolve", "SSH says publickey", "TLS certificate is not yet valid". Network
incidents feel mysterious, but each one is solved by checking layers from the
bottom up.

## Mental model: bottom-up, one layer at a time

```
 1. is it running?          systemctl status brewbot
 2. is it listening?        ss -tulpn | grep 8080     (on 127.0.0.1 or 0.0.0.0?)
 3. works locally?          curl -v http://localhost:8080/
 4. reachable from outside? curl from another machine
 5. firewall?               sudo ufw status / cloud security group
```

Stop at the first layer that fails; that is where the problem is.

## Scenario 1: cannot connect to a service

- **Connection refused**: nothing is listening there (service down, wrong port,
  or bound to 127.0.0.1).
- **Connection timed out**: packets are dropped: firewall, security group, or
  routing.
- **502 Bad Gateway** from nginx: nginx is fine, the app behind it is not (down,
  wrong upstream port).
- **504 Gateway Timeout**: the app is too slow to answer.

Time the request to separate "slow" from "down":

```bash
curl -o /dev/null -s -w "%{http_code} %{time_total}\n" http://localhost:8080/
```

An app inside a Docker container behaves the same way: if it binds `127.0.0.1`
*inside* the container, the published port cannot reach it. Bind `0.0.0.0` in
the container, then check `docker ps` for the port mapping.

## Scenario 2: name resolution fails

`curl https://api.payments.example` fails, but `curl https://203.0.113.10` works.

```bash
dig api.payments.example +short
cat /etc/resolv.conf
getent hosts api.payments.example   # includes /etc/hosts
grep payments /etc/hosts            # a stale override?
```

**Fix:** correct the resolver, remove the stale `/etc/hosts` line, or wait out a
DNS change (TTL). "It's always DNS."

## Scenario 3: SSH key refused

`Permission denied (publickey)`:

```bash
ssh -v deploy@atlas                     # client side: which keys were offered?
sudo journalctl -u ssh -n 20            # server side: why it refused (or /var/log/auth.log)
ls -ld ~ ~/.ssh ~/.ssh/authorized_keys  # home not group-writable, .ssh 700, keys 600
```

The usual causes: permissions too open on the server's `~/.ssh` or home
directory, the public key in the wrong user's `authorized_keys`, or
`AllowGroups`/`PermitRootLogin` in sshd_config excluding you.

## Scenario 4: TLS errors and wrong times

`certificate is not yet valid`, failing `apt update`, or confusing log timestamps:
the clock is off.

```bash
timedatectl                        # "System clock synchronized: yes"?
sudo timedatectl set-ntp true      # turn on NTP sync (systemd-timesyncd / chrony)
```

Also check that a certificate really has not expired:

```bash
echo | openssl s_client -connect orbit.coffee:443 -servername orbit.coffee 2>/dev/null \
  | openssl x509 -noout -dates
```

`notAfter` in the past = renew it (and automate renewal, for example certbot's
timer).

## Try it

Customers get `Connection refused` on port 8088. On atlas, `curl
localhost:8088` works and `ss -tln` shows `127.0.0.1:8088`. Which layer failed,
and what is the fix?

<details>
<summary>Show answer</summary>

Layer 2: it listens only on localhost. Change the bind address to `0.0.0.0` (or
the public interface) in the config, **restart** the process (config changes do
nothing until then), and confirm `ss -tln` shows `0.0.0.0:8088`. Then check the
firewall allows 8088.

</details>

## Common mistakes

- **Starting at the firewall.** Check the service and the listener first.
- **Editing the config and not restarting.** The running process still uses the
  old bind address.
- **Blaming DNS when the IP also fails** (or the network when only the name
  fails). Test both.
- **Ignoring the clock.** TLS, Kerberos, TOTP and log correlation all depend on
  it.

## Remember

- Bottom-up: running, listening (where?), local, remote, firewall.
- Refused = no listener; timeout = dropped; 502 = app behind proxy down.
- DNS: `getent hosts`, `/etc/hosts`, `resolv.conf`, `dig`.
- SSH: `ssh -v`, server logs, `~/.ssh` permissions. Clock: `timedatectl`.

**Self-check:**

1. What does a 502 from nginx tell you?
2. Why can `curl localhost` work while customers get refused?
3. Which command shows whether the clock is synced?
