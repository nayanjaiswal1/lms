---
kind: lab
id_key: production-debugging/lab-fa-patch-wipes-fields
course: production-debugging
section: fastapi-data-model
section_title: "Data model and validation"
section_position: 11
section_group: "FastAPI"
title: "Lab: Saving one profile field erases the others"
position: 2
estimated_minutes: 35
source:
    - docs/debug-labs.md
max_duration: 90
recipe: ../recipes/fa-patch-wipes-fields.yaml
---

Customers report that their phone number and company vanish after they edit a single field in the app. Reproduce it with one request, find where the unsent fields get written, and fix it without breaking explicit clears.
