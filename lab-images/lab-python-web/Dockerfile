# mindforge/lab-python-web — reusable Python web sandbox for backend labs.
#
# Runtime-only image: Django, FastAPI, and uvicorn are preinstalled (lab
# containers run on the isolated mindforge-labs network with no internet, so
# nothing can be pip-installed at session time), but no application code is
# baked in. Each lab ships its own app as `files:` in its canonical markdown
# doc and starts it from `setup_script` — adding a new Django/FastAPI
# exercise means adding one markdown file, never rebuilding this image.
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
      bash curl ca-certificates jq nano vim-tiny less procps ttyd \
      python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir --break-system-packages \
      "django>=5.0,<6.0" \
      "fastapi>=0.110,<1.0" \
      "uvicorn[standard]>=0.29,<1.0" \
      "httpx>=0.27,<1.0" \
      "requests>=2.31,<3.0" \
      "pytest>=8.0,<9.0"

RUN useradd --create-home --shell /bin/bash labuser \
    && mkdir -p /var/log/mindforge-lab \
    && chown -R labuser:labuser /home/labuser /var/log/mindforge-lab \
    && chmod 777 /var/log/mindforge-lab

# entrypoint.sh / app-runner.sh are identical across every lab-*-web image,
# so they live once in lab-images/shared/ — this Dockerfile's build context
# is the lab-images/ parent dir (see scripts/push-lab-images.sh) so shared/
# is reachable from here.
COPY shared/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY shared/app-runner.sh /usr/local/bin/app-runner.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/app-runner.sh

EXPOSE 7681

# --cap-drop ALL strips CAP_SETUID even from root, so the initial process UID
# must come from this directive — same reasoning as lab-k8s.
USER labuser

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
