---
kind: lesson
id_key: linux/talking-to-the-world/ssh
course: linux
section: talking-to-the-world
section_title: "Chapter 8: Talking to the World - Networking"
section_position: 8
title: "SSH: Keys, Config, Copying and Tunnels"
position: 4
estimated_minutes: 8
source:
  - ssh(1), ssh_config(5), ssh-keygen(1), ssh-copy-id(1), ssh-agent(1), scp(1), sshd(8) manual pages
---

## Why this matters

SSH is the staff door to every server. You will use it dozens of times a day.
Keys instead of passwords, a config file instead of long commands, and tunnels
for reaching private databases make you faster and safer.

## Mental model: lock and key

- You generate a **key pair**: a **private key** (stays on your laptop, never
  shared) and a **public key** (safe to hand out).
- The public key goes into the server's `~/.ssh/authorized_keys`: you are
  installing your lock on that door.
- When you connect, the server challenges you; only the matching private key can
  answer.

> **Memory hook:** the public key is the **lock** you can fit to every door; the
> private key is the **only key**: never copy it, never share it.

```
 laptop                                  atlas
 ~/.ssh/id_ed25519      (private)        ~/.ssh/authorized_keys
 ~/.ssh/id_ed25519.pub  ---copy once--->   ssh-ed25519 AAAA... you@orbit
```

## See it work

These need the OpenSSH client and a server to talk to (not in the lab image).

```bash
ssh-keygen -t ed25519 -C "you@orbit"   # make a key pair; set a passphrase
ssh-copy-id deploy@10.0.0.42           # install your public key on the server
ssh deploy@10.0.0.42                   # log in, no password needed now
ssh -p 2222 deploy@10.0.0.42           # non-standard port
ssh deploy@atlas 'df -h /'             # run one command remotely
```

`ed25519` is the modern default key type: short, fast and strong.

### The config file saves typing

```
# ~/.ssh/config
Host atlas
    HostName 10.0.0.42
    User deploy
    Port 2222
    IdentityFile ~/.ssh/atlas_ed25519
```

Now `ssh atlas`, `scp file atlas:/tmp/` and `rsync ... atlas:` just work. One
`Host` block per server; `Host *` sets defaults for all.

### Permissions SSH insists on

SSH silently ignores keys and configs that others could read or change:

| Path | Mode |
|---|---|
| `~/.ssh` | `700` |
| private key, `config`, `authorized_keys` | `600` |
| your home directory | not group- or world-writable |

### Copying files

```bash
scp backup.tar.gz atlas:/tmp/          # copy to the server
scp atlas:/var/log/syslog .            # copy from it
rsync -avz site/ atlas:/srv/site/      # better for directories (only changes)
```

### Tunnels and jumps

```bash
ssh -L 5432:localhost:5432 atlas       # local port 5432 -> atlas's localhost:5432
ssh -J bastion deploy@10.0.0.42        # hop through a bastion host
```

With the `-L` tunnel open, your laptop's `psql -h localhost` reaches atlas's
database, which only listens on atlas's localhost. Nothing extra is exposed.

### Agent: type the passphrase once

```bash
eval "$(ssh-agent)" && ssh-add ~/.ssh/atlas_ed25519
```

The agent holds the unlocked key in memory for your session. Avoid
`ForwardAgent yes` to servers you do not fully trust: root there could use your
agent.

## Try it

Write a `~/.ssh/config` entry named `atlas` for address `10.0.0.42`, user
`deploy`, port `2222`, key `~/.ssh/atlas_ed25519`, and set the right
permissions.

<details>
<summary>Show answer</summary>

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
cat >> ~/.ssh/config <<'EOF'
Host atlas
    HostName 10.0.0.42
    User deploy
    Port 2222
    IdentityFile ~/.ssh/atlas_ed25519
EOF
chmod 600 ~/.ssh/config
```

</details>

## Common mistakes

- **Copying the private key to servers.** Only the `.pub` file ever leaves your
  laptop.
- **Too-open permissions.** `Permission denied (publickey)` is often a `~/.ssh`
  or home directory that others can write.
- **No passphrase on a laptop key.** A stolen laptop becomes access to every
  server. Use a passphrase plus the agent.
- **Testing sshd changes in your only session.** Keep a second session open
  (chapter 12).

## Remember

- `ssh-keygen -t ed25519`, `ssh-copy-id`, then `ssh user@host`.
- `~/.ssh/config` Host blocks: `HostName`, `User`, `Port`, `IdentityFile`.
- `~/.ssh` 700, keys and config 600.
- `scp`/`rsync` copy; `-L` tunnels; `-J` jumps through a bastion.

**Self-check:**

1. Which key goes into `authorized_keys`?
2. What does `ssh -L 5432:localhost:5432 atlas` do?
3. Why might SSH ignore a perfectly good key?
