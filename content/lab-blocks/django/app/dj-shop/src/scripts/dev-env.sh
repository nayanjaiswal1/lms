#!/bin/bash
# Development environment for the shop. Source it in a terminal:  . scripts/dev-env.sh
# Values already present in the environment win; these are only defaults.
: "${DATABASE_URL:=postgresql://labuser@127.0.0.1:5432/app}"
: "${DJANGO_SETTINGS_MODULE:=config.settings.dev}"
: "${DJANGO_SECRET_KEY:=dev-only-secret-key-not-for-production}"
: "${PAYMENTS_BASE_URL:=http://127.0.0.1:9101}"
: "${WEBHOOK_SECRET:=whsec_mindforge_lab}"
: "${CELERY_BROKER_URL:=redis://127.0.0.1:6379/0}"
: "${REDIS_URL:=redis://127.0.0.1:6379/1}"
export DATABASE_URL DJANGO_SETTINGS_MODULE DJANGO_SECRET_KEY PAYMENTS_BASE_URL WEBHOOK_SECRET CELERY_BROKER_URL REDIS_URL
