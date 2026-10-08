# {{symptom.title}}

**Raised from monitoring and the on-call channel**

## What is happening

{{symptom.report}}

## Impact

{{symptom.impact}}

## Evidence from the application log

This is the most recent traceback the application logged while the problem was reproduced:

```
{{captured.trace}}
```

## What was already tried

{{symptom.support_tried}}

## Your job

Find the root cause, fix it, and prove the fix with a test that fails on the current code. Then fill in `INCIDENT.md`.

> The app runs without an auto-reloader so the debugger stays attached (Django `runserver --noreload`, uvicorn without `--reload`). A code fix has no effect until the process is restarted: run the **Restart app** task (Terminal > Run Task) or `mf-svc restart-workspace`, and apply new migrations first.

{{symptom.observations}}
