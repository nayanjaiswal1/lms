---
kind: lab
id_key: production-debugging/lab-dj-customer-delete
course: production-debugging
section: django-data-model
section_title: "Data model and money"
section_position: 2
section_group: "Django"
title: "Lab: Invoices vanish when a customer is deleted"
position: 2
estimated_minutes: 30
source:
    - docs/debug-labs.md
max_duration: 90
hint_penalty_pct: 10
recipe: ../recipes/dj-customer-delete.yaml
---

Support deleted a duplicate customer account in the admin, and afterwards that customer's orders and invoices were gone too. Reproduce it, find the relationship that made it possible, fix it at the source, and prove it with a test.
