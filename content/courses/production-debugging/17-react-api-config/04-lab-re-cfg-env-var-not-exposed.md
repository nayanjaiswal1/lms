---
kind: lab
id_key: production-debugging/lab-re-cfg-env-var-not-exposed
course: production-debugging
section: react-api-config
section_title: "API and configuration"
section_position: 17
section_group: "React"
title: "Lab: The staging build still calls its own host"
position: 4
estimated_minutes: 25
source:
    - docs/debug-labs.md
max_duration: 90
hint_penalty_pct: 10
recipe: ../recipes/re-cfg-env-var-not-exposed.yaml
---

The staging build ignores the configured API URL and calls relative paths. Find why the variable never reaches the code.
