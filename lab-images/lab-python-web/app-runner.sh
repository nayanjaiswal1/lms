#!/bin/bash
# Supervises the lab's application process. Lab starter files (including
# .lab/start.sh) are written by the root-run setup_script AFTER the container
# starts, so the entrypoint cannot start the app directly — this runner waits
# for the start script to appear, then keeps the app alive across crashes
# (student syntax errors, manual kills) for the whole session. Runs as
# labuser, so the app and any files it creates stay student-editable.
set -u

START=/home/labuser/work/.lab/start.sh
LOG=/var/log/mindforge-lab/app.log

while [ ! -f "$START" ]; do
  sleep 0.5
done

while true; do
  bash "$START" >>"$LOG" 2>&1 || true
  echo "[app-runner] app exited, restarting in 2s" >>"$LOG"
  sleep 2
done
