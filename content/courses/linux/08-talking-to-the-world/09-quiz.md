---
kind: quiz
id_key: linux/talking-to-the-world/quiz
course: linux
section: talking-to-the-world
section_title: "Chapter 8: Talking to the World - Networking"
section_position: 8
title: "Quiz: Networking"
position: 8
estimated_minutes: 10
pass_percentage: 70
duration_minutes: 12
source:
  - Chapter 8 lessons, plus one review question from chapter 7
questions:
  - id_key: q1
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "From your laptop, curl atlas:8080 says 'Connection refused'. On atlas, ss -tulpn shows brewbot on 127.0.0.1:8080. What is wrong?"
    options:
      - text: "brewbot listens only on localhost, so outside connections reach no listener"
        correct: true
      - text: "A firewall is dropping the packets"
      - text: "DNS resolves the wrong name"
      - text: "The server is out of memory"
    explanation: "Refused means nothing listens on that address and port. Bound to 127.0.0.1, brewbot only accepts local connections. A firewall drop shows as a timeout, a DNS problem fails before connecting, and memory is unrelated."
  - id_key: q2
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "curl to the database port hangs for a minute and then reports 'Connection timed out'. What is the most likely cause?"
    options:
      - text: "A firewall or security group silently drops the packets"
        correct: true
      - text: "The database process is stopped"
      - text: "The database password is wrong"
      - text: "The port number is below 1024"
    explanation: "Timeouts mean no answer at all, typical of a drop. A stopped service on a reachable host answers with refused immediately, passwords are checked after connecting, and port numbers do not cause timeouts."
  - id_key: q3
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Which command shows which process is listening on which port?"
    options:
      - text: "sudo ss -tulpn"
        correct: true
      - text: "ip r"
      - text: "ping localhost"
      - text: "dig localhost"
    explanation: "ss -tulpn lists TCP/UDP listeners with process names. ip r shows routes, ping tests ICMP reachability, and dig queries DNS."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "curl https://api.payments.example fails with 'Could not resolve host', but curl to its IP works. Where do you look?"
    options:
      - text: "Name resolution: getent hosts, /etc/hosts, /etc/resolv.conf, dig"
        correct: true
      - text: "The firewall"
      - text: "The TLS certificate"
      - text: "The routing table"
    explanation: "The IP works, so network, routing and firewall are fine. The failure happens before any connection, at the name lookup. TLS would fail after connecting."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "dig api.internal returns 10.0.0.9, but curl goes to 10.0.0.5. What is the most likely reason?"
    options:
      - text: "A stale line in /etc/hosts, which programs check before DNS but dig ignores"
        correct: true
      - text: "dig is broken"
      - text: "curl uses a different port"
      - text: "The TTL is negative"
    explanation: "nsswitch checks files (/etc/hosts) before DNS. getent hosts api.internal shows what programs actually use. dig asks DNS directly, ports do not affect name resolution, and TTLs are never negative."
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "SSH ignores your key and asks for a password. The server's ~/.ssh is 777 and authorized_keys is 666. What should they be?"
    options:
      - text: "~/.ssh 700 and authorized_keys 600"
        correct: true
      - text: "~/.ssh 755 and authorized_keys 777"
      - text: "Both 644"
      - text: "Permissions do not matter to SSH"
    explanation: "sshd refuses keys that other users could modify. Lock .ssh to 700 and the key files to 600; anything group- or world-writable is rejected."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "PostgreSQL on atlas listens only on 127.0.0.1:5432. How can you use psql from your laptop without opening the port to the network?"
    options:
      - text: "ssh -L 5432:localhost:5432 atlas, then connect to localhost:5432 on the laptop"
        correct: true
      - text: "ufw allow 5432 from anywhere"
      - text: "Change PostgreSQL to listen on 0.0.0.0"
      - text: "scp the database to the laptop"
    explanation: "An SSH tunnel forwards a local port through the encrypted connection to atlas's localhost. The other options expose the database or copy data around instead."
  - id_key: q8
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "You are about to run sudo ufw enable on a remote server. What must you do first?"
    options:
      - text: "sudo ufw allow 22/tcp (or OpenSSH)"
        correct: true
      - text: "Reboot"
      - text: "Stop sshd"
      - text: "Nothing; ufw never blocks SSH"
    explanation: "With a default-deny policy, enabling ufw without an SSH rule drops your own session. Rebooting or stopping sshd makes things worse, and ufw does block SSH unless allowed."
  - id_key: q9
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A health-check script runs curl http://localhost:8080/health && echo OK. It prints OK even when the app returns HTTP 500. Why?"
    options:
      - text: "curl exits 0 for any HTTP response unless -f is given"
        correct: true
      - text: "&& ignores exit codes"
      - text: "500 is a success code"
      - text: "localhost always returns OK"
    explanation: "curl only fails on transport errors by default. -f (or checking %{http_code}) makes HTTP 4xx/5xx exit non-zero. && does check exit codes, and 5xx means server error."
  - id_key: q10
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Review (chapter 7): you must copy /srv/site to a backup server every night, sending only changed files. Which command fits?"
    options:
      - text: "rsync -az /srv/site/ backup:/backups/site/"
        correct: true
      - text: "scp -r /srv/site backup:/backups/"
      - text: "tar -czf site.tar.gz /srv/site"
      - text: "cp -a /srv/site backup:/backups/"
    explanation: "rsync over SSH sends only differences. scp copies everything every time, tar only creates a local archive, and cp cannot copy to another host."
---
