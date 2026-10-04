"""Gunicorn settings for the production-mode server (see .lab/services/app.sh)."""

bind = "0.0.0.0:8000"
workers = @@mf:value gunicorn.workers=2@@
threads = @@mf:value gunicorn.threads=4@@
timeout = 30
accesslog = "-"
errorlog = "-"
