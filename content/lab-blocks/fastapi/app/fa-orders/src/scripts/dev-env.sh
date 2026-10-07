#!/bin/bash
# Development environment for the orders service. Source it in a terminal:  . scripts/dev-env.sh
# Values already present in the environment win; these are only defaults.
: "${DATABASE_URL:=postgresql://labuser@127.0.0.1:5432/app}"
: "${PAYMENTS_BASE_URL:=http://127.0.0.1:9101}"
: "${WEBHOOK_SECRET:=whsec_mindforge_lab}"
export DATABASE_URL PAYMENTS_BASE_URL WEBHOOK_SECRET
