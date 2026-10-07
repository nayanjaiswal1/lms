---
kind: lab
id_key: production-debugging/lab-fa-sequential-awaits
course: production-debugging
section: fastapi-latency
section_title: "Latency and slow APIs"
section_position: 21
section_group: "FastAPI"
title: "Lab: The storefront takes the sum of its dependencies"
position: 3
estimated_minutes: 30
source:
    - docs/debug-labs.md
max_duration: 90
recipe: ../recipes/fa-sequential-awaits.yaml
---

The home page got twice as slow after a second remote lookup was added, yet both services are fast. Show where the time goes and make the page cost only its slowest dependency.
