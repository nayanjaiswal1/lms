# mindforge/lab-node-web — reusable React/Node sandbox for frontend labs.
#
# Ships a pre-installed Vite + React scaffold at /opt/scaffold/react-app
# (lab containers run on the isolated mindforge-labs network with no
# internet, so npm install must happen at image build time). Each lab's
# setup_script copies the scaffold into the student workdir without
# clobbering the task starter files the lab shipped via `files:`, symlinks
# node_modules (a real copy would flood the file-explorer listing and the
# 3 GB disk quota), and starts the dev server. Adding a new React exercise
# means adding one markdown file, never rebuilding this image.
FROM node:22-bookworm-slim

ARG TTYD_VERSION=1.7.7

RUN apt-get update && apt-get install -y --no-install-recommends \
      bash curl ca-certificates jq nano vim-tiny less procps \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /usr/local/bin/ttyd \
      "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64" \
    && chmod +x /usr/local/bin/ttyd

RUN useradd --create-home --shell /bin/bash labuser \
    && mkdir -p /var/log/mindforge-lab \
    && chown -R labuser:labuser /home/labuser /var/log/mindforge-lab \
    && chmod 777 /var/log/mindforge-lab

COPY lab-node-web/scaffold/ /opt/scaffold/react-app/
RUN cd /opt/scaffold/react-app \
    && npm install --no-audit --no-fund \
    && chmod -R a+rX /opt/scaffold

# entrypoint.sh / app-runner.sh are identical across every lab-*-web image,
# so they live once in lab-images/shared/ — this Dockerfile's build context
# is the lab-images/ parent dir (see scripts/push-lab-images.sh) so both
# this image's own directory and shared/ are reachable from here.
COPY shared/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY shared/app-runner.sh /usr/local/bin/app-runner.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/app-runner.sh

EXPOSE 7681

# --cap-drop ALL strips CAP_SETUID even from root, so the initial process UID
# must come from this directive — same reasoning as lab-k8s.
USER labuser

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
