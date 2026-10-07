# mindforge/lab-debug — the "debug" lab kind's sandbox (docs/debug-labs.md §2).
#
# ONE image for every stack (Django / FastAPI / React / fullstack) so a single
# warm pool serves every scenario; the scenario itself is streamed in at claim
# time (workspace bundle) and at Check time (grader bundle, in a separate
# clean-room sandbox). Everything a scenario can need is baked in — lab
# containers have no egress, so nothing can be installed at session time.
#
# Build context is lab-images/ (see scripts/push-lab-images.sh) so this file
# can reuse lab-node-web/scaffold.
#
# Every version is pinned; upstream artifacts were checked to exist on
# 2026-09-29 (openvscode-server v1.96.4 linux-x64, Node v22.12.0 SHASUMS256,
# Open VSX ms-python.python@2024.22.1 universal, ms-python.debugpy@2024.14.0
# linux-x64, both compatible with VS Code 1.96). The build still fails loudly
# (set -e / sha256 checks) rather than producing a partial image.
FROM ubuntu:24.04

ARG NODE_VERSION=22.12.0
ARG OPENVSCODE_VERSION=1.96.4
# Open VSX extension ids@versions installed at build time.
ARG VSX_PYTHON=ms-python.python@2024.22.1
ARG VSX_DEBUGPY=ms-python.debugpy@2024.14.0
# Self-hosted webview origin template, deploy specific (docs/debug-labs.md §2
# "Webview CDN"), e.g. https://{{uuid}}.webview.labs.example.com. Empty = leave
# VS Code's default (webviews then load from *.vscode-cdn.net).
ARG WEBVIEW_BASE_URL_TEMPLATE=""

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      bash curl ca-certificates jq nano vim-tiny less procps git xz-utils tar gzip \
      ttyd \
      python3 python3-pip python3-venv python3-dev build-essential libpq-dev \
      postgresql-16 postgresql-client-16 postgresql-contrib \
      redis-server \
    && rm -rf /var/lib/apt/lists/* \
    # The distro postgres/redis units are never used: the image supervisor runs
    # its own labuser-owned instances (services.d/).
    && rm -rf /var/lib/postgresql/16/main \
    && python3 --version | grep -q "Python 3.12"

# Node 22 (pinned tarball, checksum verified against nodejs.org's SHASUMS256).
RUN set -eux; \
    f="node-v${NODE_VERSION}-linux-x64.tar.xz"; \
    cd /tmp; \
    curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/${f}"; \
    curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt"; \
    grep " ${f}\$" SHASUMS256.txt | sha256sum -c -; \
    tar -xJf "${f}" -C /usr/local --strip-components=1 --no-same-owner; \
    rm -f "${f}" SHASUMS256.txt; \
    node --version | grep -q "^v22\."

# Python debug/web stack (all pinned).
RUN pip3 install --break-system-packages \
      "Django==5.1.4" \
      "djangorestframework==3.15.2" \
      "django-debug-toolbar==4.4.6" \
      "whitenoise==6.8.2" \
      "gunicorn==23.0.0" \
      "fastapi==0.115.6" \
      "uvicorn[standard]==0.34.0" \
      "SQLAlchemy==2.0.36" \
      "asyncpg==0.30.0" \
      "psycopg[binary]==3.2.3" \
      "alembic==1.14.0" \
      "pydantic==2.10.3" \
      "pydantic-settings==2.7.0" \
      "httpx==0.28.1" \
      "requests==2.32.3" \
      "tenacity==9.0.0" \
      "PyJWT==2.10.1" \
      "bcrypt==4.2.1" \
      "celery==5.4.0" \
      "redis==5.2.1" \
      "debugpy==1.8.11" \
      "pytest==8.3.4" \
      "pytest-django==4.9.0" \
      "pytest-asyncio==0.25.0" \
      "ruff==0.8.4"

# Scenario-build formatters: ruff (above) formats rendered Python, prettier
# formats rendered JS/TS (mf-build skips a language whose formatter is absent).
RUN npm install -g --no-audit --no-fund prettier@3.4.2 \
    && prettier --version | grep -q "^3\.4\.2"

# Offline wheelhouse for version-bump scenarios (e.g. pydantic 1.10, older
# Django) — students `pip install --no-index --find-links /opt/wheels <pkg>`.
# --no-deps: the scenario's own pins name what they need; the base stack
# above already provides the shared dependencies.
RUN mkdir -p /opt/wheels \
    && pip3 download --no-deps --dest /opt/wheels \
         "pydantic==1.10.19" \
         "Django==4.2.17" \
         "SQLAlchemy==1.4.54" \
         "pytz==2024.2" \
         "django-cors-headers==4.6.0" \
    && chmod -R a+rX /opt/wheels

# React/vitest scaffold (root-owned, shared with lab-node-web).
COPY lab-node-web/scaffold/ /opt/scaffold/react-app/
RUN cd /opt/scaffold/react-app \
    && npm install --no-audit --no-fund \
    && chmod -R a+rX /opt/scaffold

# openvscode-server (pinned). --connection-token-file is set by services.d/ide.sh.
RUN set -eux; \
    d="openvscode-server-v${OPENVSCODE_VERSION}-linux-x64"; \
    curl -fsSL -o /tmp/ide.tar.gz \
      "https://github.com/gitpod-io/openvscode-server/releases/download/openvscode-server-v${OPENVSCODE_VERSION}/${d}.tar.gz"; \
    mkdir -p /opt/openvscode-server; \
    tar -xzf /tmp/ide.tar.gz -C /opt/openvscode-server --strip-components=1 --no-same-owner; \
    rm -f /tmp/ide.tar.gz; \
    /opt/openvscode-server/bin/openvscode-server --version

COPY lab-debug/bin/mf-patch-product.py /tmp/mf-patch-product.py

# IDE extensions from Open VSX, then the marketplace is switched off: the
# runtime has no egress, and an installed-extension-only IDE is the intent.
RUN set -eux; \
    mkdir -p /opt/ide/extensions /opt/ide/data; \
    /opt/openvscode-server/bin/openvscode-server \
      --extensions-dir /opt/ide/extensions --user-data-dir /opt/ide/data \
      --install-extension "${VSX_PYTHON}" \
      --install-extension "${VSX_DEBUGPY}"; \
    python3 /tmp/mf-patch-product.py "${WEBVIEW_BASE_URL_TEMPLATE}"

RUN useradd --create-home --shell /bin/bash labuser \
    && mkdir -p /var/log/mindforge-lab /var/lib/mindforge-pg /opt/ide/data \
    && chown -R labuser:labuser /home/labuser /var/log/mindforge-lab /var/lib/mindforge-pg /opt/ide \
    && chmod 777 /var/log/mindforge-lab \
    && chmod 700 /var/lib/mindforge-pg

# Root-owned, student-immutable platform code: supervisor, service scripts,
# grade.sh and the probe library. labuser can read/execute, never modify.
COPY lab-debug/bin/ /opt/mindforge/bin/
COPY lab-debug/services.d/ /opt/mindforge/services.d/
COPY lab-debug/grade.sh /opt/mindforge/grade.sh
COPY lab-debug/grader/ /opt/mindforge/grader/
COPY lab-debug/mf-build/ /opt/mindforge/mf-build/
COPY lab-debug/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chown -R root:root /opt/mindforge /usr/local/bin/entrypoint.sh \
    && chmod -R go-w /opt/mindforge \
    && chmod 755 /opt/mindforge/grade.sh /opt/mindforge/bin/* /opt/mindforge/services.d/*.sh /usr/local/bin/entrypoint.sh \
    && ln -s /opt/mindforge/bin/mf-svc /usr/local/bin/mf-svc \
    && ln -s /opt/mindforge/bin/lab-ready /usr/local/bin/lab-ready \
    && find /opt/mindforge/mf-build -type d -exec chmod 755 {} + \
    && find /opt/mindforge/mf-build -type f -exec chmod 644 {} + \
    && python3 -m compileall -q /opt/mindforge/grader /opt/mindforge/mf-build

# React labs: the vitest helpers in grader/js (setup.js, harness.js) import react
# and @testing-library from the baked scaffold, reachable through this symlink
# (same realpath as the app's own imports, so there is one React instance).
RUN ln -s /opt/scaffold/react-app/node_modules /opt/mindforge/grader/js/node_modules

# ttyd :7681 (authenticated), IDE :3000 (connection-token authenticated).
EXPOSE 7681 3000

# --cap-drop ALL strips CAP_SETUID even from root, so the initial process UID
# must come from this directive — same reasoning as the other lab images.
USER labuser
WORKDIR /home/labuser

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
