---
kind: lesson
id_key: linux/hardening/ssh-hardening
course: linux
section: hardening
section_title: "Chapter 12: Locking Down Atlas - Security Hardening"
section_position: 12
title: "Hardening SSH: Keys Only, No Root, fail2ban"
position: 1
estimated_minutes: 7
source:
  - sshd(8), sshd_config(5) manual pages; fail2ban documentation (fail2ban.org)
---

## Why this matters

Within minutes of getting a public IP, atlas sees thousands of SSH password
guesses from bots. If one account has a weak password, they get in. SSH
hardening takes five lines and closes the most attacked door on the internet.

## Mental model: the staff door

- **Keys only**: no password can be guessed if passwords are not accepted.
- **No root at the door**: staff log in as themselves, then use `sudo` (which is
  logged).
- **Only staff**: name who may log in.
- **A bouncer for repeat offenders**: fail2ban bans IPs after failed attempts.

## See it work

Ubuntu reads drop-in files from `/etc/ssh/sshd_config.d/`. Put your changes in
one file instead of editing the main config:

```
# /etc/ssh/sshd_config.d/10-hardening.conf
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 20
AllowGroups ssh-users
X11Forwarding no
```

| Setting | Effect |
|---|---|
| `PasswordAuthentication no` | keys only; no password guessing |
| `KbdInteractiveAuthentication no` | closes the other password-prompt path |
| `PermitRootLogin no` | log in as yourself, then `sudo` |
| `MaxAuthTries 3` | disconnect after 3 failed attempts |
| `AllowGroups ssh-users` | only members of this group may log in |
| `X11Forwarding no` | turn off features you do not use |

### Apply it without locking yourself out

```bash
sudo sshd -t                        # 1. syntax check: silent means OK
sudo sshd -T | grep -Ei 'passwordauth|permitroot|maxauth'   # 2. effective settings
sudo systemctl reload ssh           # 3. reload (existing sessions stay open)
# 4. in a NEW terminal: ssh atlas   -> must still work before you close the old one
```

Expected output of step 2:

```
maxauthtries 3
permitrootlogin no
passwordauthentication no
```

The first matching value wins in `sshd_config`, and drop-ins are read where the
main file has its `Include` line (at the top on Ubuntu), so a drop-in beats
later lines in the main file. `sshd -T` shows what is really in effect.

### fail2ban: ban repeat offenders

```bash
sudo apt install fail2ban
sudo tee /etc/fail2ban/jail.local <<'EOF'
[sshd]
enabled  = true
maxretry = 5
findtime = 10m
bantime  = 1h
EOF
sudo systemctl restart fail2ban
sudo fail2ban-client status sshd
```

fail2ban reads the auth log (or journal), counts failures per IP and adds a
firewall rule to block offenders.

### See the attacks

```bash
sudo grep 'Failed password' /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | head
sudo journalctl -u ssh --since today | grep -c 'Invalid user'
sudo lastb | head                     # failed logins (from /var/log/btmp)
```

The first line is chapter 3's top-N pipeline: the field four from the end is the
source IP in OpenSSH's "Failed password ... from IP port N ssh2" line.

Moving SSH to another port reduces log noise but is not security; bots find it.
Restrict by source network in the firewall where possible, or use a VPN or
bastion host.

## Try it

You set `PasswordAuthentication no` in `/etc/ssh/sshd_config.d/10-hardening.conf`,
but `sshd -T` still shows `passwordauthentication yes`. What could cause it?

<details>
<summary>Show answer</summary>

Another file sets it first. The first value sshd reads wins, so a drop-in that
sorts earlier (for example `01-legacy.conf`) or a line placed before the
`Include` in the main file overrides yours. Search: `sudo grep -ri passwordauthentication /etc/ssh/`. Rename yours to
sort first or remove the conflicting line, then `sshd -t` and reload.

</details>

## Common mistakes

- **Disabling passwords before your key works.** Test key login first.
- **Closing your only session after reloading.** Always test from a second
  terminal.
- **Forgetting `sshd -t`.** A typo stops sshd from starting at the next restart.
- **Trusting a non-standard port as protection.** It only reduces noise.

## Remember

- Drop-in `/etc/ssh/sshd_config.d/10-hardening.conf`: keys only, no root,
  `MaxAuthTries`, `AllowGroups`.
- `sshd -t` (syntax), `sshd -T` (effective config), reload, test in a new
  session.
- fail2ban bans IPs after repeated failures.
- Count attackers with grep + awk + `sort | uniq -c`.

**Self-check:**

1. Why disable both `PasswordAuthentication` and `KbdInteractiveAuthentication`?
2. Which command shows the settings sshd will really use?
3. What does fail2ban do?
