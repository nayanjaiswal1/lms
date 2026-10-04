#!/bin/bash
# The shop web app. Supervised by the lab runtime; stdout and stderr land in /var/log/mindforge-lab/app.log (written by the supervisor).
# Development mode runs Django under debugpy (attach on :5678) without the
# autoreloader; MF_SERVER=gunicorn (production mode) runs gunicorn instead.
set -uo pipefail
cd /home/labuser/work || exit 1
. scripts/dev-env.sh
# Environment overrides written by the lab (production mode, missing variables, ...).
if [ -f .lab/env ]; then . .lab/env; fi

until pg_isready -q -h 127.0.0.1 -p 5432; do sleep 0.3; done

if [ "${MF_COLLECTSTATIC:-0}" = "1" ]; then
  python3 manage.py collectstatic --noinput || echo "collectstatic failed" >&2
fi

if [ "${MF_SERVER:-runserver}" = "gunicorn" ]; then
  exec python3 -m gunicorn config.wsgi:application -c gunicorn.conf.py
fi
exec python3 -m debugpy --listen 127.0.0.1:5678 manage.py runserver 0.0.0.0:8000 --noreload
