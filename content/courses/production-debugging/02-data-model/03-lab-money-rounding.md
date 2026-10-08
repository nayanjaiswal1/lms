---
kind: lab
id_key: production-debugging/lab-dj-money-rounding
course: production-debugging
section: django-data-model
section_title: "Data model and money"
section_position: 2
section_group: "Django"
title: "Lab: Order totals are one cent off"
position: 3
estimated_minutes: 45
source:
    - docs/debug-labs.md
max_duration: 90
hint_penalty_pct: 10
recipe: ../recipes/dj-money-rounding.yaml
---

Finance found orders whose tax is one cent lower than the tax rule says. Find where the shop loses exactness, fix it, and write the test that would have caught it.
