---
kind: lab
id_key: production-debugging/lab-fa-blocking-call-in-async-handler
course: production-debugging
section: fastapi-latency
section_title: "Latency and slow APIs"
section_position: 21
section_group: "FastAPI"
title: "Lab: The API stalls while shoppers search"
position: 2
estimated_minutes: 40
source:
    - docs/debug-labs.md
max_duration: 90
recipe: ../recipes/fa-blocking-call-in-async-handler.yaml
---

Everything gets slow in waves that line up with product search, the health check included. Prove which call holds the event loop, move it off the loop, and keep the synonym feature working.
