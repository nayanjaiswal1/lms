# {{symptom.title}}

**Escalated from the support queue**

## What we are seeing

{{symptom.report}}

## Where it happens

{{symptom.where}}

## What we expected

{{symptom.expected}}

## What support already tried

{{symptom.support_tried}}

## Your job

Reproduce the problem in this workspace, find the root cause in the code, fix it, and prove the fix with a test that fails
on the current code. Then fill in `INCIDENT.md`.

> The app runs without an auto-reloader so the debugger stays attached (Django `runserver --noreload`, uvicorn without `--reload`). A code fix has no effect until the process is restarted: run the **Restart app** task (Terminal > Run Task) or `mf-svc restart-workspace`, and apply new migrations first.

{{symptom.observations}}
