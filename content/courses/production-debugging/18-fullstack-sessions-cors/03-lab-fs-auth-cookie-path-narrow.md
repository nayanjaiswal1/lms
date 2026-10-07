---
kind: lab
id_key: production-debugging/lab-fs-auth-cookie-path-narrow
course: production-debugging
section: fullstack-sessions-cors
section_title: "Sessions, cookies and CORS"
section_position: 18
section_group: "Fullstack"
title: "Lab: Sign-in succeeds, then Orders and Profile say \"Sign in to continue"
position: 3
estimated_minutes: 30
source:
    - docs/debug-labs.md
max_duration: 90
recipe: ../recipes/fs-auth-cookie-path-narrow.yaml
---

Reported by a customer: "Sign-in succeeds, then Orders and Profile say "Sign in to continue". Reproduce it in the running shop, find where the browser and the API disagree, and fix it at the source.
