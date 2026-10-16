---
kind: lesson
id_key: linux/storeroom/packages
course: linux
section: storeroom
section_title: "Chapter 7: The Storeroom - Packages, Disks and Backups"
section_position: 7
title: "Installing Software: apt, dpkg, dnf and rpm"
position: 0
estimated_minutes: 8
source:
  - apt(8), apt-get(8), dpkg(1), dpkg-query(1), dnf(8), rpm(8), unattended-upgrades documentation (Ubuntu Server Guide)
---

## Why this matters

> **Monday, week 2.** A delivery of new disks arrives, and the dev team wants
> software installed. Rhea: "Before you install anything, know what's already in
> the storeroom. And never let a disk fill up silently."

On Linux you rarely download installers from websites. The package manager
installs signed software from trusted repositories, resolves dependencies, and
patches security holes. Knowing it also answers "which version do we run?" and
"where did this file come from?"

## Mental model: the menu and the order

- A **package** is an archive of files plus metadata: name, version,
  dependencies, install scripts.
- A **repository** is a signed online catalogue of packages.
- The **high-level tool** (`apt`, `dnf`) downloads from repositories and solves
  dependencies. The **low-level tool** (`dpkg`, `rpm`) installs a single package
  file and keeps the database of what is installed.

| | Debian / Ubuntu | RHEL / Fedora / Rocky | Alpine |
|---|---|---|---|
| Package format | `.deb` | `.rpm` | `.apk` |
| High-level tool | `apt` | `dnf` (older: `yum`) | `apk` |
| Low-level tool | `dpkg` | `rpm` | - |

> **Memory hook:** `apt update` reads the **menu**, `apt upgrade` **orders** the
> new dishes. Always update before you install.

## See it work

```bash
sudo apt update                  # refresh the package lists (the menu)
sudo apt install nginx           # install, with dependencies
sudo apt upgrade                 # upgrade everything installed
sudo apt remove nginx            # remove, keep config files
sudo apt purge nginx             # remove including config
sudo apt autoremove              # remove dependencies nobody needs anymore
apt search redis                 # find packages
apt show nginx                   # details: version, size, dependencies
apt list --upgradable            # what would upgrade
```

### Asking dpkg what is installed

These work without root, so try them in the lab:

```bash
dpkg -l bash                          # is it installed? which version?
dpkg-query -W -f='${Version}\n' bash  # just the version
dpkg -L jq | head -3                  # files installed by a package
dpkg -S /usr/bin/jq                   # which package owns this file?
```

Expected output (versions differ):

```
ii  bash           5.2.21-2ubuntu4 amd64        GNU Bourne Again SHell
5.2.21-2ubuntu4
/.
/usr
/usr/bin
jq: /usr/bin/jq
```

`ii` means desired = install, status = installed. The RHEL equivalents are
`rpm -q bash`, `rpm -ql PACKAGE`, `rpm -qf FILE`, and `dnf provides FILE` for
packages that are not installed yet.

### Repositories and keys

Repositories are listed in `/etc/apt/sources.list.d/` (Ubuntu 24.04 uses the
`ubuntu.sources` file). Third-party repos come with a signing key; the key is
what makes a download trustworthy.

### Keeping a server patched

```bash
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades   # enable automatic security updates
apt-mark hold postgresql-16                       # freeze one package's version
cat /var/run/reboot-required 2>/dev/null          # does an update need a reboot?
```

`/var/log/apt/history.log` and `/var/log/dpkg.log` record every install: the
first place to look when "it broke after the update".

### Other ways software arrives

`snap` and `flatpak` (self-contained apps), language package managers (`pip`,
`npm`), container images, and building from source
(`./configure && make && sudo make install`, into `/usr/local`). On servers,
prefer the distro package when one exists: it gets security updates.

## Try it

Which package installed `/usr/bin/jq`, and which version of `bash` is installed?
Answer both with dpkg tools.

<details>
<summary>Show answer</summary>

```bash
dpkg -S /usr/bin/jq | cut -d: -f1      # jq
dpkg-query -W -f='${Version}\n' bash   # 5.2.21-2ubuntu4 (yours may differ)
```

</details>

## Common mistakes

- **`apt install` without `apt update` first.** Old lists point to package
  versions the mirror deleted: 404 errors.
- **`apt upgrade` on production at peak time.** Services restart. Schedule it,
  and read what will change first.
- **Mixing `pip install` (as root) with distro Python packages.** It can break
  system tools. Use virtual environments.
- **Adding random third-party repositories.** Each one can push any code as root.

## Remember

- `apt update` then `apt install`; `remove` keeps config, `purge` removes it.
- `dpkg -l` / `-L` / `-S` answer installed? / which files? / which package?
- RHEL: `dnf install`, `rpm -q`, `rpm -ql`, `rpm -qf`.
- Enable unattended security upgrades; check `/var/log/apt/history.log` after
  changes.

**Self-check:**

1. What is the difference between `apt update` and `apt upgrade`?
2. Which command tells you which package owns a file?
3. What is the difference between `remove` and `purge`?
