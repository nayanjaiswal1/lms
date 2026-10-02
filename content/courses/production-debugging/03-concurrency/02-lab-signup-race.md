---
kind: lab
id_key: production-debugging/lab-dj-signup-race
course: production-debugging
section: django-concurrency
section_title: "Concurrency"
section_position: 3
section_group: "Django"
title: "Lab: A burst of signups crashes with IntegrityError"
position: 2
estimated_minutes: 45
source:
    - docs/debug-labs.md
max_duration: 90
recipe: ../recipes/dj-signup-race.yaml
---

After a newsletter went out, a few visitors got a server error when signing up. Reproduce the burst, read the real traceback, and fix the underlying race, not the symptom.
