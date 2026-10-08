---
kind: lab
id_key: production-debugging/lab-dj-perf-order-list
course: production-debugging
section: django-performance
section_title: "Performance"
section_position: 1
section_group: "Django"
title: "Lab: The order list page is slow for repeat customers"
position: 2
estimated_minutes: 40
source:
    - docs/debug-labs.md
max_duration: 90
hint_penalty_pct: 10
recipe: ../recipes/dj-perf-order-list.yaml
---

Loyal customers say the **My orders** page has become painfully slow. You get the support ticket, the shop's source with its real git history, a database with data, and a browser IDE. Reproduce it, find out why it gets slower with every order, fix it, and prove the fix with a test that fails on the broken code.
