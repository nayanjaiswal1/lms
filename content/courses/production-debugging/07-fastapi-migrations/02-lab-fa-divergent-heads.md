---
kind: lab
id_key: production-debugging/lab-fa-divergent-heads
course: production-debugging
section: fastapi-migrations
section_title: "Migrations (Alembic)"
section_position: 7
section_group: "FastAPI"
title: "Lab: The release is blocked by multiple Alembic heads"
position: 2
estimated_minutes: 30
source:
    - docs/debug-labs.md
max_duration: 90
recipe: ../recipes/fa-divergent-heads.yaml
---

Two order data fixes were merged on the same day and now `alembic upgrade head` refuses to run. Read the graph, fix it without losing history, and add a check so a fork cannot reach a release silently.
