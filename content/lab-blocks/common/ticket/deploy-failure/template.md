# {{symptom.title}}

**Raised by the release engineer**

## What happened

{{symptom.report}}

## Output

```
{{symptom.output}}
```

## Impact

{{symptom.impact}}

## What was already tried

{{symptom.support_tried}}

## Your job

Find the root cause, fix it so the deployment works from an empty database and from an existing one, and prove it with a test
or check that fails on the current code. Then fill in `INCIDENT.md`.

> The app runs without an auto-reloader so the debugger stays attached (Django `runserver --noreload`, uvicorn without `--reload`). A code fix has no effect until the process is restarted: run the **Restart app** task (Terminal > Run Task) or `mf-svc restart-workspace`, and apply new migrations first.

{{symptom.observations}}
