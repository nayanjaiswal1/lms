---
kind: lesson
id_key: linux/hardening/mac-and-sandboxing
course: linux
section: hardening
section_title: "Chapter 12: Locking Down Atlas - Security Hardening"
section_position: 12
title: "Beyond Permissions: AppArmor, SELinux and systemd Sandboxing"
position: 3
estimated_minutes: 7
source:
  - apparmor(7), aa-status(8), selinux(8), getenforce(8), restorecon(8), audit2why(1) manual pages
  - systemd.exec(5) "Sandboxing", systemd-analyze(1) "security"
---

## Why this matters

File permissions say what a **user** may do. If nginx (user `www-data`) is
hacked, the attacker can do everything `www-data` can, including reading every
file that user can read. **Mandatory access control** and **sandboxing** limit
what a specific **program** may do, even when the permissions would allow it.

## Mental model: a job description on top of the key ring

- **DAC** (discretionary access control) = classic rwx and ACLs. The owner
  decides. Chapter 4.
- **MAC** (mandatory access control) = a policy written by the admin that the
  program cannot change: "nginx may read `/srv/www` and `/etc/nginx`, write
  `/var/log/nginx`, and nothing else". Both checks must pass.

```
 request from nginx to read /home/rhea/notes.txt
   DAC (rwx):      others may read     -> allowed
   MAC (AppArmor): not in nginx profile -> DENIED
```

Two MAC systems:

| | AppArmor | SELinux |
|---|---|---|
| Default on | Ubuntu, Debian, SUSE | RHEL, Fedora, Rocky, Alma |
| Policy based on | file **paths** per program (profiles) | **labels** on every file and process |
| Status | `sudo aa-status` | `getenforce`, `sestatus` |
| Modes | enforce / complain | enforcing / permissive / disabled |

## See it work

### AppArmor (Ubuntu)

```bash
sudo aa-status | head
```

```
apparmor module is loaded.
48 profiles are loaded.
46 profiles are in enforce mode.
   /usr/sbin/cupsd
   /usr/sbin/mysqld
...
```

Denials appear in the kernel log:

```bash
sudo journalctl -k | grep -i 'apparmor="DENIED"'
```

Profiles live in `/etc/apparmor.d/`. `sudo aa-complain /usr/sbin/mysqld` logs
instead of blocking while you fix a profile; `aa-enforce` turns it back on.

### SELinux (RHEL family)

```bash
getenforce                        # Enforcing / Permissive / Disabled
ls -Z /var/www/html/index.html    # the file's label
sudo ausearch -m avc -ts recent   # denials
sudo restorecon -Rv /var/www/html # reset labels to the policy default
```

The classic SELinux bug: you `mv` files from your home into `/var/www/html`;
they keep the home-directory label, and the web server gets "Permission denied"
although rwx looks fine. `restorecon` fixes it. Do **not** fix it with
`setenforce 0`; that switches off protection for the whole machine.

### systemd sandboxing: cheap and per service

Many sandbox options are one line each in a unit file:

```ini
[Service]
User=brewbot
NoNewPrivileges=yes          # cannot gain privileges via SUID binaries
ProtectSystem=strict         # / is read-only for this service...
ReadWritePaths=/var/lib/brewbot /var/log/brewbot   # ...except these
ProtectHome=yes              # /home, /root invisible
PrivateTmp=yes               # its own /tmp
CapabilityBoundingSet=       # no capabilities at all
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
```

```bash
systemd-analyze security brewbot
```

```
→ Overall exposure level for brewbot.service: 3.1 OK
```

The score drops from around 9.6 ("UNSAFE") as you add options. Add them one at a
time and check the service still works.

## Try it

On a RHEL server, nginx returns 403 for a page you just moved from your home
directory. `ls -l` shows `-rw-r--r-- nginx nginx`. What is the likely cause and
fix?

<details>
<summary>Show answer</summary>

SELinux labels: the moved file kept its `user_home_t` label, which nginx may not
read. Check with `ls -Z` and `ausearch -m avc -ts recent`, then fix with
`sudo restorecon -Rv /usr/share/nginx/html` (or the site's directory). Leave
SELinux enforcing.

</details>

## Common mistakes

- **Disabling SELinux/AppArmor at the first denial.** Read the denial and fix the
  label or the profile.
- **`mv` vs `cp` on SELinux systems.** `mv` keeps old labels; run `restorecon`.
- **Adding every sandbox option at once.** The service breaks and you do not
  know which line did it.

## Remember

- DAC = rwx/ACLs (user-based); MAC = admin policy per program; both must allow.
- AppArmor (Ubuntu): profiles by path, `aa-status`, denials in the kernel log.
- SELinux (RHEL): labels, `getenforce`, `ls -Z`, `restorecon`, `ausearch -m avc`.
- systemd sandboxing: `NoNewPrivileges`, `ProtectSystem`, `ProtectHome`,
  `PrivateTmp`; score with `systemd-analyze security`.

**Self-check:**

1. What does MAC add on top of normal permissions?
2. Which command fixes wrong SELinux labels?
3. What does `ProtectSystem=strict` do?
