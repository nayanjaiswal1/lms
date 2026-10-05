# {{symptom.title}}

**Reported from support on the Shop Console**

## What happened

{{symptom.report}}

## Where in the app

{{symptom.where}}

## What should happen

{{symptom.expected}}

## Already ruled out

{{symptom.support_tried}}

## Your job

The console (React, `src/`) and the API (FastAPI, `backend/`) live in this one repository and the lab runs both: the
browser preview is on port 5173 and Vite proxies `/api` to the API on port 8000. Reproduce the problem (the preview,
`curl`, or a test), find which side is at fault, fix it, and prove the fix with a test that fails on the current code
(`npx vitest run` for the frontend, `python3 -m pytest` for the backend). Then fill in `INCIDENT.md`.

{{symptom.observations}}
