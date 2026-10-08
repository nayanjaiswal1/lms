---
kind: lab
id_key: production-debugging/lab-fa-order-list-n-plus-one
course: production-debugging
section: fastapi-performance
section_title: "Performance (SQLAlchemy)"
section_position: 8
section_group: "FastAPI"
title: "Lab: The order list is slow for repeat customers"
position: 2
estimated_minutes: 40
source:
    - docs/debug-labs.md
max_duration: 90
hint_penalty_pct: 10
recipe: ../recipes/fa-order-list-n-plus-one.yaml
---

Loyal customers say the orders list got painfully slow. Count what the endpoint asks the database, find out why it grows with every order, fix it, and prove the fix with a test that fails on the broken code.
