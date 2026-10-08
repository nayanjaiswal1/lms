---
kind: lab
id_key: production-debugging/lab-re-state-form-keeps-previous-customer
course: production-debugging
section: react-state
section_title: "State and identity"
section_position: 15
section_group: "React"
title: "Lab: The customer editor shows the previous customer"
position: 3
estimated_minutes: 30
source:
    - docs/debug-labs.md
max_duration: 90
hint_penalty_pct: 10
recipe: ../recipes/re-state-form-keeps-previous-customer.yaml
---

Selecting another customer leaves the previous customer's details in the form, and saving would overwrite the wrong record. Find where the form state is kept.
