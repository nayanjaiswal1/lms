---
kind: lab
id_key: production-debugging/lab-fa-bcrypt-event-loop
course: production-debugging
section: fastapi-async
section_title: "Async and concurrency"
section_position: 9
section_group: "FastAPI"
title: "Lab: The whole API freezes whenever somebody logs in"
position: 2
estimated_minutes: 40
source:
    - docs/debug-labs.md
max_duration: 90
hint_penalty_pct: 10
recipe: ../recipes/fa-bcrypt-event-loop.yaml
---

Monday mornings make every endpoint sluggish, the health check included. Find what the slow periods have in common, prove it with a measurement, and fix it without weakening the password hashing.
