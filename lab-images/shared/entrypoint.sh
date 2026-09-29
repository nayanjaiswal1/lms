#!/bin/bash
set -euo pipefail

# setup_script runs as root but --cap-drop ALL strips CAP_DAC_OVERRIDE, so
# root cannot traverse labuser's 0750 home to write starter files. Loosen the
# home to 0755 and pre-create a world-writable workdir — the same fix as
# lab-images/lab-k8s/entrypoint.sh (see docs/labs.md, Container Runtime).
chmod 755 /home/labuser
mkdir -p /home/labuser/work
chmod 777 /home/labuser/work

/usr/local/bin/app-runner.sh >/var/log/mindforge-lab/app-runner.log 2>&1 &

# ttyd credential (docs/labs.md "Proxy ↔ Container Channel Security";
# docs/debug-labs.md "Pre-existing problems" + Phase 0): every lab container
# shares the mindforge-labs bridge network, so an unauthenticated ttyd here
# is a shell any other student's container can open. The backend writes
# "user:pass" into this file via `docker exec` (labs.writeTTYDCredential)
# once this container is bound to a real session — for a warm-pool
# container that happens at claim time, which can be long after this script
# already started, so wait for it rather than ever starting ttyd bare. No
# timeout: an unclaimed warm container is expected to sit here indefinitely
# until claimed or reaped by the orphan-cleanup job, and nothing has a
# reason to connect to this port before that.
cred_file=/home/labuser/.mf-ttyd-cred
while [ ! -s "$cred_file" ]; do
  sleep 0.5
done
cred="$(cat "$cred_file")"

cd /home/labuser/work
exec ttyd -W -p 7681 -c "$cred" bash
