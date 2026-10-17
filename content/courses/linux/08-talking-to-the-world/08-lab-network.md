---
kind: lesson
id_key: linux/talking-to-the-world/lesson
course: linux
section: talking-to-the-world
section_title: "Chapter 8: Talking to the World - Networking"
section_position: 8
title: "Lab: Prove Atlas Is Listening"
position: 7
estimated_minutes: 25
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
    - id_key: port-check
      title: Which doors are open?
      points: 20
      is_stateful: true
      description: >-
        Test which of the ports 8080, 8081 and 9090 on 127.0.0.1 accept a TCP
        connection right now, and save the open port numbers, one per line, into
        /home/labuser/work/answers/open-ports.txt. nc is not installed, so use curl
        or bash's /dev/tcp.
      verification_script: |
        f=/home/labuser/work/answers/open-ports.txt
        [ -f $f ] || exit 1
        want=$(for p in 8080 8081 9090; do timeout 2 bash -c "</dev/tcp/127.0.0.1/$p" 2>/dev/null && echo $p; done)
        [ -n "$want" ] && [ "$(grep -o '[0-9]\+' $f | sort -n | tr '\n' ' ')" = "$(echo $want | tr ' ' '\n' | sort -n | tr '\n' ' ')" ]
      hint_context: "for p in 8080 8081 9090; do timeout 2 bash -c \"</dev/tcp/127.0.0.1/$p\" 2>/dev/null && echo $p; done > answers/open-ports.txt - the web server from task 1 must still be running."
      explanation_context: Opening /dev/tcp/HOST/PORT makes bash attempt a TCP connection, so it doubles as a port tester on minimal machines. A refused connection fails at once; a firewalled one would hang until the timeout.
      solution_script: |
        for p in 8080 8081 9090; do timeout 2 bash -c "</dev/tcp/127.0.0.1/$p" 2>/dev/null && echo $p; done > /home/labuser/work/answers/open-ports.txt
---

## Why this matters

The payment provider says they cannot reach atlas. Before blaming them, you
prove what is listening, what it answers, and how you would reach it over SSH.
Each task is checked automatically.

## Before you start

```bash
ls ~/work/site
ss -tln
```

What this does: shows the two files you will serve, and confirms nothing listens
on 8080 yet.

## Task 1: open the shop's front door

Serve `~/work/site` over HTTP on port 8080 with Python's built-in web server,
in the background so you keep your prompt.

[[lab-task:1]]

Check yourself: `ss -tln | grep 8080` shows a listener.

## Task 2: read the response headers

Save only the HTTP response headers of `http://localhost:8080/` into
`~/work/answers/headers.txt`.

[[lab-task:2]]

What you should see:

```
$ curl -I http://localhost:8080/
HTTP/1.0 200 OK
Server: SimpleHTTP/0.6 Python/3.12.3
Content-type: text/html
...
```

## Task 3: ask the API a question

Fetch `http://localhost:8080/status.json` with curl and extract only the
`version` field with jq. Save that value (no quotes) into
`answers/api-version.txt`.

[[lab-task:3]]

## Task 4: a shortcut for SSH

Create `~/.ssh/config` with a host entry `atlas` for address `10.0.0.42`, user
`deploy`, port `2222`, key `~/.ssh/atlas_ed25519`. `~/.ssh` must be 700 and
the config 600. (There is no server to connect to; the check reads your file.)

[[lab-task:4]]

## Task 5: which doors are open?

Test which of the ports 8080, 8081 and 9090 on `127.0.0.1` accept a TCP
connection, and save the open ones, one per line, into
`answers/open-ports.txt`. `nc` is not installed; lesson 7 showed the bash
`/dev/tcp` trick.

[[lab-task:5]]

## Remember

- A server is a process listening on a port; `ss -tln` proves it.
- `curl -I` headers, `curl -s | jq -r .field` JSON.
- `~/.ssh/config` with 700/600 permissions.
- `bash -c '</dev/tcp/HOST/PORT'` tests a port anywhere.

> **End of day 8.** `ss -tulpn` showed brewbot listening on 127.0.0.1 only, and
> nginx's config had the wrong upstream port. One fix and the payment provider
> is happy. Rhea: "You're doing a lot of things by hand. Tomorrow, teach atlas
> to do them itself." Tom's note: "Lazy admins write scripts."
