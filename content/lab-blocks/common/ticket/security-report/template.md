# {{symptom.title}}

**Finding from the security review**

## Finding

{{symptom.finding}}

## How it was reproduced

{{symptom.steps}}

## Impact

{{symptom.impact}}

## What was already tried

{{symptom.support_tried}}

## Your job

Confirm the finding, fix the root cause (not just the reported request), and prove it with a test that fails on the current
code. Then fill in `INCIDENT.md`.

> The app runs without an auto-reloader so the debugger stays attached (Django `runserver --noreload`, uvicorn without `--reload`). A code fix has no effect until the process is restarted: run the **Restart app** task (Terminal > Run Task) or `mf-svc restart-workspace`, and apply new migrations first.

{{symptom.observations}}
