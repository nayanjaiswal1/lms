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

{{symptom.observations}}
