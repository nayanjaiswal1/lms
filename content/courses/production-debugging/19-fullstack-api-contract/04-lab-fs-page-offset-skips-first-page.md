---
kind: lab
id_key: production-debugging/lab-fs-page-offset-skips-first-page
course: production-debugging
section: fullstack-api-contract
section_title: "The API contract"
section_position: 19
section_group: "Fullstack"
title: "Lab: Our newest orders are missing from the order history"
position: 4
estimated_minutes: 30
source:
    - docs/debug-labs.md
max_duration: 90
hint_penalty_pct: 10
recipe: ../recipes/fs-page-offset-skips-first-page.yaml
---

Reported by a customer: "Our newest orders are missing from the order history". Reproduce it in the running shop, find where the browser and the API disagree, and fix it at the source.
