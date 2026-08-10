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

cd /home/labuser/work
exec ttyd -W -p 7681 bash
