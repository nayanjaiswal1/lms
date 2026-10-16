---
kind: lesson
id_key: linux/incident-week/access-and-postmortem
course: linux
section: incident-week
section_title: "Chapter 13: Incident Week - Troubleshooting Playbook"
section_position: 13
title: "Locked Out, Recovery Mode, and the Post-Mortem"
position: 5
estimated_minutes: 6
source:
  - visudo(8), systemd.special(7) (rescue.target, emergency.target) manual pages
  - Google SRE Book, chapter 15 "Postmortem Culture - Learning from Failure" (sre.google)
---

## Why this matters

Sometimes you break your own access: a bad sudoers file, a firewall rule, an
fstab typo that stops the boot. And when the fire is out, the most valuable
step is the one most teams skip: writing down what happened so it never
happens again.

## Mental model: the spare key and the logbook

- Every server needs a **spare key**: a way in that does not depend on SSH, sudo
  or the network (console, recovery mode).
- Every incident ends with a **logbook entry**: the post-mortem.

## Scenario: locked out of sudo

You broke `/etc/sudoers` or removed yourself from the `sudo` group.

- Never edit sudoers without `visudo`: it refuses to save a broken file. Keep
  rules in small `/etc/sudoers.d/` files, edited with `visudo -f`.
- If it happens anyway: use another admin account, `pkexec visudo` on desktops,
  or boot into **recovery mode** (or the cloud provider's serial console) to fix
  it as root.

## Scenario: the server does not boot

```
 GRUB menu  -> pick an older kernel (Advanced options)
            -> or edit the kernel line (press e) and append:
                 systemd.unit=rescue.target      root shell, basic system
                 systemd.unit=emergency.target   root shell, root mounted read-only
```

From emergency mode, fix the cause (often a bad `/etc/fstab` line):

```bash
mount -o remount,rw /
nano /etc/fstab          # comment out the broken line, or add nofail
mount -a                 # test
systemctl reboot
```

On cloud servers, the **serial console** shows the boot messages and gives you
this shell; for some providers you instead attach the disk to a rescue VM.

## Scenario: locked out by the firewall or SSH config

Use the cloud console or out-of-band access, undo the last change
(`ufw disable`, restore the sshd drop-in), and next time keep a second session
open and test from a new one before closing the old one (chapter 12).

## The post-mortem

When the fire is out, write down:

| Section | Content |
|---|---|
| Summary | one paragraph: what broke, impact, duration |
| Timeline | timestamps: detection, actions, recovery |
| Root cause | the real cause, not the trigger ("no log rotation", not "disk filled") |
| What went well / badly | detection speed, tooling, communication |
| Action items | owner + date: a logrotate rule, an alert, a script, a doc |

**No blame.** Systems fail and people learn. Ask "how did our system allow
this?" rather than "who did it?", or people will hide mistakes next time.

> **Memory hook:** a post-mortem without action items is a story, not a fix.

## Try it

After Black Friday's full-disk outage, which is the better root cause:
"brewbot's debug log filled the disk" or "debug logging was enabled in
production and the brewbot log had no rotation or size alert"? Name two action
items.

<details>
<summary>Show answer</summary>

The second: it names the conditions that allowed the trigger. Action items, each
with an owner and a date: add a logrotate rule (or journald limits) for brewbot;
alert at 80% disk; turn off debug logging in production config; add a CI check
for the log level.

</details>

## Common mistakes

- **No out-of-band access tested before you need it.** Check the cloud console
  works today.
- **Editing sudoers, sshd and firewall in one go.** Change one, test, then the
  next.
- **Post-mortems that blame a person.** You lose the honest timeline.
- **Action items without owners.** They never happen.

## Remember

- Sudoers only via `visudo`; recovery mode, serial console as spare keys.
- Boot problems: older kernel in GRUB, `rescue.target`, `emergency.target`; fix
  fstab with `nofail` and `mount -a`.
- Post-mortem: summary, timeline, root cause, lessons, action items with owners.
- Blameless.

**Self-check:**

1. Why use `visudo` instead of a normal editor?
2. Which kernel argument boots into a minimal root shell?
3. What makes a root cause better than a trigger?
