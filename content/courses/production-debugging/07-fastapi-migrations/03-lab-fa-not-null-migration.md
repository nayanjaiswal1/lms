---
kind: lab
id_key: production-debugging/lab-fa-not-null-migration
course: production-debugging
section: fastapi-migrations
section_title: "Migrations (Alembic)"
section_position: 7
section_group: "FastAPI"
title: "Lab: A migration works in staging and crashes on production"
position: 3
estimated_minutes: 40
source:
    - docs/debug-labs.md
max_duration: 90
hint_penalty_pct: 10
recipe: ../recipes/fa-not-null-migration.yaml
---

A revision adds a column to the products table. It ran fine everywhere except on production, which has years of data. Reproduce the failure from a populated database, fix the revision, and prove it with a test.
