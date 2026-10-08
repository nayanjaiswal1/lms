---
kind: lab
id_key: production-debugging/lab-fa-payments-timeout
course: production-debugging
section: fastapi-service-calls
section_title: "Service calls and errors"
section_position: 10
section_group: "FastAPI"
title: "Lab: Paying hangs when the payments provider is slow"
position: 2
estimated_minutes: 40
source:
    - docs/debug-labs.md
max_duration: 90
hint_penalty_pct: 10
recipe: ../recipes/fa-payments-timeout.yaml
---

During a provider slowdown the pay button spins forever and later the whole API stops answering. Reproduce the slow provider, find what the call waits on, and bound it.
