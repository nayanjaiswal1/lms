---
kind: lab
id_key: production-debugging/lab-fa-order-idor
course: production-debugging
section: fastapi-config-security
section_title: "Configuration and security"
section_position: 12
section_group: "FastAPI"
title: "Lab: Any customer can read any order"
position: 3
estimated_minutes: 35
source:
    - docs/debug-labs.md
max_duration: 90
recipe: ../recipes/fa-order-idor.yaml
---

A security review found that changing the order number in the URL returns somebody else's order. Confirm it with two accounts, fix the root cause, and prove it with a test that fails on the vulnerable code.
