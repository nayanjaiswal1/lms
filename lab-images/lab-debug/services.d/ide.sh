#!/bin/bash
# openvscode-server on :3000, authenticated by a per-session connection token
# the backend writes at claim time (labs.writeIDECredential — a DIFFERENT
# HMAC domain than ttyd's). labproxy recomputes it and injects it on requests
# to this port only; the browser never sees it. Wait for it rather than ever
# starting the IDE unauthenticated (an unclaimed warm container idles here).
set -euo pipefail

TOKEN_FILE=/home/labuser/.mf-ide-cred

while [ ! -s "$TOKEN_FILE" ]; do
  sleep 0.5
done

exec /opt/openvscode-server/bin/openvscode-server \
  --host 0.0.0.0 \
  --port 3000 \
  --connection-token-file "$TOKEN_FILE" \
  --extensions-dir /opt/ide/extensions \
  --user-data-dir /opt/ide/data \
  --disable-telemetry \
  --accept-server-license-terms
