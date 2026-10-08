---
kind: lab
id_key: production-debugging/lab-fs-state-profile-version-ignored
course: production-debugging
section: fullstack-data-state
section_title: "Data and state"
section_position: 20
section_group: "Fullstack"
title: "Lab: Saving my profile on my laptop erased the phone number I just changed on my phone"
position: 4
estimated_minutes: 30
source:
    - docs/debug-labs.md
max_duration: 90
hint_penalty_pct: 10
recipe: ../recipes/fs-state-profile-version-ignored.yaml
---

Reported by a customer: "Saving my profile on my laptop erased the phone number I just changed on my phone". Reproduce it in the running shop, find where the browser and the API disagree, and fix it at the source.
