---
kind: lesson
id_key: linux/night-shift/unit-files
course: linux
section: night-shift
section_title: "Chapter 6: The Night Shift - systemd, Logs and Schedules"
section_position: 6
title: "Writing a Unit File, and Overriding One Safely"
position: 2
estimated_minutes: 8
source:
  - systemd.unit(5), systemd.service(5), systemd.exec(5), systemctl(1) "edit" manual pages
---

## Why this matters

Brewbot was started by Tom with `nohup` from his shell. It did not restart after
a crash, did not start after reboot, and its logs went nowhere. A ten-line unit
file fixes all three.

## Mental model: a recipe card for the night manager

A unit file is a small INI file with three sections:

```
 [Unit]     WHAT is it and WHEN does it start (order, dependencies)
 [Service]  HOW to run it (command, user, restart policy, environment)
 [Install]  WHERE it hooks in when you run `systemctl enable`
```

Where unit files live:

| Path | Who writes it |
|---|---|
| `/usr/lib/systemd/system/` (also `/lib/systemd/system/`) | packages; do not edit |
| `/etc/systemd/system/` | you; wins over the package version |
| `/etc/systemd/system/NAME.service.d/*.conf` | drop-in overrides |

## See it work

```ini
# /etc/systemd/system/brewbot.service
[Unit]
Description=Orbit Coffee order bot
# start after networking is up
After=network.target

[Service]
ExecStart=/opt/brewbot/bin/brewbot
# never run apps as root
User=brewbot
# come back if it crashes
Restart=on-failure
RestartSec=5
Environment=PORT=8080

[Install]
# "enable" hooks it into normal boot
WantedBy=multi-user.target
```

Line by line:

- `After=network.target`: start after networking. `After` only orders; add
  `Wants=` or `Requires=` to also pull another unit in.
- `ExecStart=`: the command, with a **full path**. systemd does not use your
  shell's PATH or `.bashrc`.
- `User=`: run as a dedicated, unprivileged user.
- `Restart=on-failure`: restart when it crashes (non-zero exit or signal), wait
  `RestartSec` seconds first.
- `WantedBy=multi-user.target`: `systemctl enable` creates a link so the normal
  boot target pulls brewbot in.

Comments must be on their own line: systemd would treat
`After=network.target # comment` as part of the value.

Activate it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now brewbot
systemctl status brewbot
```

### Overriding a package's unit: drop-ins

Never edit files under `/usr/lib/systemd/system/`; the next package update
overwrites them. Add a **drop-in** instead:

```bash
sudo systemctl edit nginx
```

This opens an editor for `/etc/systemd/system/nginx.service.d/override.conf`.
Only write what you change:

```ini
[Service]
LimitNOFILE=65536
Restart=always
```

`systemctl edit` runs `daemon-reload` for you. `systemctl cat nginx` shows the
original plus every drop-in. To **replace** a list setting such as `ExecStart`,
clear it first with an empty `ExecStart=` line, then set the new value.

### A few production settings worth knowing

```ini
[Service]
EnvironmentFile=/etc/brewbot/env     # KEY=value lines, keeps secrets out of the unit
WorkingDirectory=/opt/brewbot
UMask=0027
MemoryMax=512M                       # cgroup limit (chapter 10)
NoNewPrivileges=yes                  # chapter 12: basic sandboxing
ProtectSystem=strict
```

`systemd-analyze security brewbot` scores how locked down a service is.

## Try it

Write the `[Service]` section that runs `/opt/brewbot/bin/brewbot` as user
`brewbot` and restarts it only when it fails. Which section and line makes
`enable` work?

<details>
<summary>Show answer</summary>

```ini
[Service]
ExecStart=/opt/brewbot/bin/brewbot
User=brewbot
Restart=on-failure
```

`enable` needs `[Install]` with `WantedBy=multi-user.target`. Without an
`[Install]` section, `systemctl enable` refuses.

</details>

## Common mistakes

- **Relative paths or shell syntax in `ExecStart`.** No PATH, no pipes, no `&&`.
  Use a full path, or `ExecStart=/bin/bash -c '...'` if you truly need a shell.
- **Backgrounding the program.** `ExecStart=/opt/app &` or a program that
  daemonizes itself confuses systemd. Run it in the foreground (or set
  `Type=forking` for old-style daemons).
- **Editing the vendor unit in `/usr/lib`.** Lost on the next update. Use
  `systemctl edit`.
- **Forgetting `daemon-reload` after editing by hand.**

## Remember

- `[Unit]` what/when, `[Service]` how, `[Install]` where enable hooks in.
- Your units go in `/etc/systemd/system/`; overrides via `systemctl edit`.
- Key lines: `ExecStart` (full path), `User`, `Restart=on-failure`,
  `WantedBy=multi-user.target`.
- `systemctl cat` shows the effective unit.

**Self-check:**

1. Why must `ExecStart` use a full path?
2. Where does `systemctl edit nginx` write its file?
3. What does `After=` do, and what does it not do?
