---
kind: lab
id_key: production-debugging/lab-dj-report-days
course: production-debugging
section: django-data-model
section_title: "Data model and money"
section_position: 2
section_group: "Django"
title: "Lab: Evening orders land on tomorrow's report"
position: 4
estimated_minutes: 45
source:
    - docs/debug-labs.md
max_duration: 90
hint_penalty_pct: 10
recipe: ../recipes/dj-report-days.yaml
---

The daily revenue report never matches the payment provider's settlement day by day. Find out which day each order is counted on and why.
