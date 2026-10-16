---
kind: lesson
id_key: linux/night-shift/boot
course: linux
section: night-shift
section_title: "Chapter 6: The Night Shift - systemd, Logs and Schedules"
section_position: 6
title: "How Atlas Boots: Firmware, GRUB, Kernel, systemd"
position: 0
estimated_minutes: 6
source:
  - bootup(7), systemd.special(7), systemd-analyze(1), dmesg(1) manual pages
  - The Linux Kernel documentation, "Using the initial RAM disk (initrd)"
---

## Why this matters

> **Friday night, on call for the first time.** Your phone buzzes at 2:07am:
> *brewbot is down, no orders are coming in.* Tom's note said "services, logs,
> and the clock".

When a server does not come back after a reboot, you need to know which stage
failed: firmware, bootloader, kernel or services. Each stage has its own tools
and its own error messages.

## Mental model: four runners in a relay

```
 power on
   |
 [1] BIOS / UEFI        firmware checks hardware, finds a boot disk
   |
 [2] GRUB (bootloader)  menu; loads the kernel + initramfs from /boot
   |
 [3] Kernel             detects hardware, uses the initramfs to find
   |                    and mount the real root filesystem
 [4] systemd (PID 1)    starts every service in dependency order
   |
 [5] target reached     multi-user.target (server) or graphical.target (desktop)
   |
 login prompt
```

> **Memory hook:** "**B**ig **G**reen **K**ettles **S**team": **B**IOS,
> **G**RUB, **K**ernel, **S**ystemd.

- The **initramfs** is a tiny temporary root filesystem in RAM. It holds the
  drivers needed to reach the real disk (RAID, LVM, encryption).
- A **target** is a named group of units that represents a system state.
  `multi-user.target` = networking and services, no desktop. Older systems
  called these **runlevels** (3 = multi-user, 5 = graphical).

## See it work

```bash
systemctl get-default          # which target we boot into
systemd-analyze                # how long boot took
systemd-analyze blame | head   # slowest units first
```

Expected output (similar):

```
multi-user.target
Startup finished in 3.1s (kernel) + 9.8s (userspace) = 12.9s
multi-user.target reached after 9.6s in userspace.
          5.104s cloud-init.service
          2.012s postgresql@16-main.service
```

### Kernel messages

```bash
sudo dmesg -T | tail             # kernel ring buffer, human timestamps
journalctl -k -b                 # same, from the journal, this boot
journalctl --list-boots          # every boot the journal remembers
journalctl -b -1 -p err          # errors from the PREVIOUS boot
```

`dmesg` is where disk errors, out-of-memory kills, driver problems and hardware
faults show up. `-b -1` (previous boot) is how you investigate a crash after
the machine has rebooted.

### Rescue paths

- Pick an older kernel in the **GRUB menu** if a new kernel fails.
- Boot a **rescue** target (`systemd.unit=rescue.target` on the kernel command
  line) for a root shell with minimal services.
- On cloud servers, use the provider's **serial console**: it shows the boot
  messages even when SSH is down.

`cat /proc/cmdline` shows the kernel command line the machine booted with.

## Try it

Atlas rebooted at 3am after a crash and is fine now. Which command shows the
errors logged just before the crash?

<details>
<summary>Show answer</summary>

```bash
journalctl -b -1 -p err
```

`-b -1` selects the previous boot, `-p err` keeps error priority and worse.
This needs a persistent journal (lesson 4).

</details>

## Common mistakes

- **Rebooting to "see if it helps" before reading logs.** Without a persistent
  journal, the evidence disappears with the reboot.
- **Confusing the kernel and the distro version.** A failed boot after an update
  is often a new kernel; the old one is still in the GRUB menu.
- **Ignoring `dmesg`.** Disk and memory problems are logged by the kernel, not by
  your application.

## Remember

- Firmware, GRUB, kernel (+ initramfs), systemd, target.
- `systemd-analyze blame` = slow boot; `systemctl get-default` = target.
- `dmesg -T` / `journalctl -k` = kernel messages; `journalctl -b -1` = last
  boot.
- Rescue: older kernel in GRUB, `rescue.target`, serial console.

**Self-check:**

1. What is the initramfs for?
2. Which target does a server normally boot into?
3. Where do you look for disk errors?
