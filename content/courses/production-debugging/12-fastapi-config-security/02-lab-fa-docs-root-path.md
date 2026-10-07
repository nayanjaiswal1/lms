---
kind: lab
id_key: production-debugging/lab-fa-docs-root-path
course: production-debugging
section: fastapi-config-security
section_title: "Configuration and security"
section_position: 12
section_group: "FastAPI"
title: "Lab: The API docs are blank behind the gateway"
position: 2
estimated_minutes: 35
source:
    - docs/debug-labs.md
max_duration: 90
recipe: ../recipes/fa-docs-root-path.yaml
---

Partners say the interactive docs are empty in staging and production but fine on laptops. Look at what the page asks the gateway for, find why, and fix it for every prefix, not just this one.
