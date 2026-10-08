---
kind: lab
id_key: production-debugging/lab-dj-stock-oversell
course: production-debugging
section: django-concurrency
section_title: "Concurrency"
section_position: 3
section_group: "Django"
title: "Lab: The last unit is sold twice"
position: 3
estimated_minutes: 60
source:
    - docs/debug-labs.md
max_duration: 90
hint_penalty_pct: 10
recipe: ../recipes/dj-stock-oversell.yaml
---

During a flash sale, more units were sold than existed. It only happens under load. Build a way to reproduce it, find the lost update, and fix it in the database, not in Python.
