---
kind: lesson
id_key: linux/talking-to-the-world/lesson
course: linux
section: talking-to-the-world
section_title: "Chapter 8: Talking to the World"
section_position: 8
title: IP, Ports, DNS, curl, SSH and Firewalls
position: 0
estimated_minutes: 50
source:
  - ip(8), ss(8), ping(8), dig(1), curl(1), ssh(1), ssh_config(5), ssh-keygen(1), ufw(8) manual pages
  - hosts(5), resolv.conf(5) manual pages
lab:
  lab_type: terminal
  environment: mindforge/lab-debug:1
  max_duration: 45
  max_resets: 3
  is_required: false
  workspace_layout: console
  files:
    - path: site/index.html
      content: |
        <!doctype html>
        <title>Orbit Coffee</title>
        <h1>Orbit Coffee - fresh beans, roasted on atlas</h1>
    - path: site/status.json
      content: |
        {"service": "brewbot", "version": "2.4.1", "healthy": true, "orders_today": 128}
  setup_script: |
    w=/home/labuser/work
    rm -rf $w/answers
    mkdir -p $w/answers
  tasks:
    - id_key: start-server
      title: Open the shop's front door
      points: 25
      is_stateful: true
      description: Serve the /home/labuser/work/site directory over HTTP on port 8080 using Python's built-in web server, running in the background so you keep your prompt.
      verification_script: |
        curl -sf --max-time 3 http://localhost:8080/ | grep -q 'Orbit Coffee'
      hint_context: python3 -m http.server 8080 --directory /home/labuser/work/site serves a folder. Put nohup in front and an ampersand at the end to background it.
      explanation_context: A server is just a process that listens on a port. localhost (127.0.0.1) is the loopback address - traffic that never leaves the machine.
      solution_script: |
        nohup python3 -m http.server 8080 --directory /home/labuser/work/site >/dev/null 2>&1 &
        sleep 1
    - id_key: headers
      title: Read the response headers
      points: 20
      is_stateful: true
      description: Save only the HTTP response headers of http://localhost:8080/ into answers/headers.txt.
      verification_script: |
        f=/home/labuser/work/answers/headers.txt
        grep -q 'HTTP/1.[01] 200' $f && grep -qi '^Server: SimpleHTTP' $f && ! grep -q '<h1>' $f
      hint_context: curl -I sends a HEAD request and prints only the headers. Redirect the output with >.
      explanation_context: Headers carry the status code, content type and server name. curl -I is the fastest way to ask "is it up, and what is answering?"
      solution_script: |
        curl -sI http://localhost:8080/ > /home/labuser/work/answers/headers.txt
    - id_key: json-api
      title: Ask the API a question
      points: 25
      is_stateful: true
      description: Fetch http://localhost:8080/status.json with curl and use jq to extract only the version field. Save that value (no quotes) into answers/api-version.txt.
      verification_script: |
        [ "$(tr -d '[:space:]' < /home/labuser/work/answers/api-version.txt)" = 2.4.1 ]
      hint_context: curl -s URL | jq -r .version - the -s hides curl's progress bar and jq -r prints raw text without quotes.
      explanation_context: curl talks HTTP, jq slices JSON. Together they replace a browser for checking any API from a terminal.
      solution_script: |
        curl -s http://localhost:8080/status.json | jq -r .version > /home/labuser/work/answers/api-version.txt
    - id_key: ssh-config
      title: A shortcut for SSH
      points: 30
      is_stateful: true
      description: >-
        Create ~/.ssh/config with a host entry named atlas that connects to the
        address 10.0.0.42 as the user deploy on port 2222, using the key file
        ~/.ssh/atlas_ed25519. The ~/.ssh directory must be accessible only by you
        (700) and the config file readable and writable only by you (600).
      verification_script: |
        c=$HOME/.ssh/config
        [ "$(stat -c %a $HOME/.ssh)" = 700 ] && [ "$(stat -c %a $c)" = 600 ] &&
        grep -Eq '^\s*Host\s+atlas\s*$' $c && grep -Eiq '^\s*HostName\s+10\.0\.0\.42\s*$' $c &&
        grep -Eiq '^\s*User\s+deploy\s*$' $c && grep -Eiq '^\s*Port\s+2222\s*$' $c &&
        grep -Eiq '^\s*IdentityFile\s+~/\.ssh/atlas_ed25519\s*$' $c
      hint_context: One line Host atlas, then indented lines HostName, User, Port and IdentityFile. mkdir -p ~/.ssh, chmod 700 ~/.ssh, chmod 600 ~/.ssh/config.
      explanation_context: With this entry, ssh atlas expands to ssh -i ~/.ssh/atlas_ed25519 -p 2222 deploy@10.0.0.42. SSH refuses keys and configs that other users can read or write.
      solution_script: |
        mkdir -p ~/.ssh && chmod 700 ~/.ssh
        printf 'Host atlas\n    HostName 10.0.0.42\n    User deploy\n    Port 2222\n    IdentityFile ~/.ssh/atlas_ed25519\n' > ~/.ssh/config
        chmod 600 ~/.ssh/config
---

> **Tuesday, week 2.** The payment provider emails: *we can't reach your server*. Rhea: "Before you blame them, prove atlas is listening. Every service has an address and a door number." Tom's note: *every door has a number*.

## Addresses and ports

```
   IP address = the building           port = the door
   10.0.0.42                            :443  (HTTPS)

   client 203.0.113.5:51522  ------>  atlas 10.0.0.42:443  (nginx)
```

| Address | Meaning |
|---|---|
| `127.0.0.1` / `::1` | **localhost** - this machine, traffic never leaves it |
| `10.x`, `172.16-31.x`, `192.168.x` | private networks (offices, clouds, home) |
| `0.0.0.0` (in "listening on") | every interface on this machine |
| `/24` in `10.0.0.0/24` | subnet mask: the first 24 bits are the network, 256 addresses |

Well-known ports - worth memorising:

| Port | Service | Port | Service |
|---|---|---|---|
| 22 | SSH | 443 | HTTPS |
| 25 | SMTP (mail) | 3306 | MySQL |
| 53 | DNS | 5432 | PostgreSQL |
| 80 | HTTP | 6379 | Redis |

Ports below 1024 are **privileged**: only root can listen on them. That is why apps often listen on 8080 behind nginx on 80/443.

> **Memory hook:** the IP is the **street address of the café**, the port is **which door** - front door 80 for walk-ins, the locked side door 22 for staff (SSH).

## Inspecting the network

```bash
ip a                     # interfaces and their IP addresses (old: ifconfig)
ip r                     # routing table - "default via 10.0.0.1" is the gateway
ss -tulpn                # listening TCP/UDP ports and which process owns them
ss -tn                   # current TCP connections
ping -c 3 10.0.0.1       # is the host reachable? (ICMP, may be blocked)
traceroute example.com   # every hop on the way (or tracepath / mtr)
hostname -I              # this machine's IPs
```

`ss -tulpn` is the most useful networking command on a server:

```
Netid State  Local Address:Port  Process
tcp   LISTEN 0.0.0.0:22          users:(("sshd",pid=812))
tcp   LISTEN 127.0.0.1:8080      users:(("brewbot",pid=1040))
tcp   LISTEN 0.0.0.0:443         users:(("nginx",pid=901))
```

Note `127.0.0.1:8080` - brewbot only listens on localhost, so nobody outside can reach it directly. That is correct here (nginx forwards to it), but it is also the number one reason for "the app runs but I can't connect".

## Talking HTTP with curl

```bash
curl http://localhost:8080/             # GET, print the body
curl -I https://orbit.coffee            # headers only
curl -v https://orbit.coffee            # verbose: DNS, TLS, request, response
curl -s URL | jq .                      # quiet + pretty JSON
curl -X POST -H 'Content-Type: application/json' -d '{"qty":2}' URL
curl -o file.tar.gz URL                 # save to a file (or wget URL)
curl -sf URL || echo "DOWN"             # -f: fail on HTTP errors, great in scripts
```

[[lab-task:1]]

[[lab-task:2]]

What you should see:

```
$ curl -I http://localhost:8080/
HTTP/1.0 200 OK
Server: SimpleHTTP/0.6 Python/3.12.x
Content-type: text/html
...
```

[[lab-task:3]]

## DNS: names to numbers

```
 orbit.coffee  --->  resolver (/etc/resolv.conf)  --->  203.0.113.10
```

```bash
dig orbit.coffee +short       # ask DNS (or: nslookup, host)
dig MX orbit.coffee           # mail servers
getent hosts orbit.coffee     # resolve the way programs do (includes /etc/hosts)
cat /etc/resolv.conf          # which DNS server this machine asks
cat /etc/hosts                # local overrides, checked BEFORE DNS
```

`/etc/hosts` lets you pin a name to an IP on one machine - great for testing a new server before switching DNS:

```
127.0.0.1   localhost
10.0.0.42   atlas atlas.internal
```

> **Memory hook:** "**It's always DNS.**" When a name fails but the IP works, the problem is name resolution, not the network.

## SSH: the staff door

```bash
ssh deploy@10.0.0.42                 # log in
ssh -p 2222 deploy@10.0.0.42         # non-standard port
ssh-keygen -t ed25519 -C "you@orbit" # make a key pair: private + .pub
ssh-copy-id deploy@10.0.0.42         # install your public key on the server
scp backup.tar.gz deploy@atlas:/tmp/ # copy a file over SSH
ssh -L 5432:localhost:5432 atlas     # tunnel: reach atlas's DB on your localhost:5432
```

Key-based login: your **private key** (`~/.ssh/id_ed25519`) never leaves your laptop; the **public key** goes into the server's `~/.ssh/authorized_keys`.

> **Memory hook:** the public key is the **lock** you can hand out to every door; the private key is the **only key** - never copy it, never share it.

Permissions matter - SSH silently refuses keys if they are too open: `~/.ssh` **700**, private key and `config` **600**, `authorized_keys` **600**.

A `~/.ssh/config` saves typing:

```
Host atlas
    HostName 10.0.0.42
    User deploy
    Port 2222
    IdentityFile ~/.ssh/atlas_ed25519
```

Now `ssh atlas` and `scp file atlas:/tmp/` just work.

[[lab-task:4]]

Hardening the server side (`/etc/ssh/sshd_config`, then `sudo systemctl reload ssh`): `PasswordAuthentication no`, `PermitRootLogin no`. Keep a second session open while you test - a typo can lock you out.

## Firewalls

```bash
sudo ufw status verbose          # Ubuntu's friendly firewall
sudo ufw allow 22/tcp            # ALWAYS allow SSH before enabling!
sudo ufw allow 443/tcp
sudo ufw allow from 10.0.0.0/24 to any port 5432    # DB only from the office
sudo ufw enable
sudo firewall-cmd --list-all     # RHEL's firewalld equivalent
sudo iptables -L -n              # the low-level rules underneath (nftables on newer systems)
```

Cloud servers have a second firewall outside the machine (security groups). "Connection timed out" usually means a firewall dropped it; "connection refused" means you reached the machine but nothing listens on that port.

> **Memory hook:** **refused = nobody home** (wrong port or service down). **timed out = the gate is locked** (firewall or routing).

> **End of day 8.** `ss -tulpn` showed brewbot listening on 127.0.0.1 only, and nginx's config had the wrong upstream port. One fix and the payment provider is happy. Rhea: "You're doing a lot of things by hand. Tomorrow - teach atlas to do them itself." Tom's note: "Lazy admins write scripts."
