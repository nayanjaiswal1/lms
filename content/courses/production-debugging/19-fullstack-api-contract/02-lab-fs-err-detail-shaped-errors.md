---
kind: lab
id_key: production-debugging/lab-fs-err-detail-shaped-errors
course: production-debugging
section: fullstack-api-contract
section_title: "The API contract"
section_position: 19
section_group: "Fullstack"
title: "Lab: Error messages are gone - not-found and forbidden failures show \"Request failed\""
position: 2
estimated_minutes: 30
source:
    - docs/debug-labs.md
max_duration: 90
hint_penalty_pct: 10
recipe: ../recipes/fs-err-detail-shaped-errors.yaml
---

Reported by a customer: "Error messages are gone - missing and blocked requests just show "Request failed"". Reproduce it in the running shop, find where the browser and the API disagree, and fix it at the source.
