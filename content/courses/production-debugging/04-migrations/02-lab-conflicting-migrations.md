---
kind: lab
id_key: production-debugging/lab-dj-conflicting-migrations
course: production-debugging
section: django-migrations
section_title: "Migrations"
section_position: 4
section_group: "Django"
title: "Lab: The release is blocked by conflicting migrations"
position: 2
estimated_minutes: 30
source:
    - docs/debug-labs.md
max_duration: 90
recipe: ../recipes/dj-conflicting-migrations.yaml
---

Two data migrations were merged on the same day and now migrate refuses to run. Read the graph, fix it without losing history, and add a check so it cannot happen silently again.
