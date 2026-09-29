#!/bin/bash
set -euo pipefail

# Same home/workdir preparation as lab-images/shared/entrypoint.sh: setup
# runs with --cap-drop ALL, so root cannot traverse labuser's 0750 home.
chmod 755 /home/labuser
mkdir -p /home/labuser/work
chmod 777 /home/labuser/work

# Image-local supervisor: postgres, redis, the IDE (services.d/) and any
# scenario service scripts that appear under work/.lab/services/.
/opt/mindforge/bin/mf-supervisor >/var/log/mindforge-lab/supervisor.log 2>&1 &

# ttyd credential — identical contract to lab-images/shared/entrypoint.sh
# (docs/labs.md "Proxy <-> Container Channel Security"): the backend writes
# "user:pass" here at claim time (labs.writeTTYDCredential); never start ttyd
# without it. An unclaimed warm container waits here indefinitely by design.
# The IDE's own token (~/.mf-ide-cred, written by labs.writeIDECredential) is
# awaited the same way by services.d/ide.sh, so the IDE port is never
# reachable unauthenticated either.
cred_file=/home/labuser/.mf-ttyd-cred
while [ ! -s "$cred_file" ]; do
  sleep 0.5
done
cred="$(cat "$cred_file")"

cd /home/labuser/work
exec ttyd -W -p 7681 -c "$cred" bash
