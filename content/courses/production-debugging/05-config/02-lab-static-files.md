---
kind: lab
id_key: production-debugging/lab-dj-static-files
course: production-debugging
section: django-config
section_title: "Configuration and deployment"
section_position: 5
section_group: "Django"
title: "Lab: Production has no styles or scripts"
position: 2
estimated_minutes: 30
source:
    - docs/debug-labs.md
max_duration: 90
hint_penalty_pct: 10
recipe: ../recipes/dj-static-files.yaml
---

The site renders as unstyled text on production only. Work out what serves static files in each environment and restore it properly, without turning DEBUG on.
