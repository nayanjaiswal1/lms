---
kind: lab
id_key: production-debugging/lab-re-hooks-object-dependency-loop
course: production-debugging
section: react-hooks
section_title: "React hooks"
section_position: 13
section_group: "React"
title: "Lab: The Reports page hammers the API"
position: 4
estimated_minutes: 30
source:
    - docs/debug-labs.md
max_duration: 90
hint_penalty_pct: 10
recipe: ../recipes/re-hooks-object-dependency-loop.yaml
---

The Reports page sends the same request again and again and the API team is alerting. Find what restarts the effect on every render.
