---
kind: lab
id_key: production-debugging/lab-dj-backfill-slugs
course: production-debugging
section: django-migrations
section_title: "Migrations"
section_position: 4
section_group: "Django"
title: "Lab: A migration that only fails on production data"
position: 3
estimated_minutes: 60
source:
    - docs/debug-labs.md
max_duration: 90
recipe: ../recipes/dj-backfill-slugs.yaml
---

The migration passed on every developer machine and in staging and aborted on production. Recreate production-shaped data, find the flaw in the backfill, and fix the migration without weakening the model.
