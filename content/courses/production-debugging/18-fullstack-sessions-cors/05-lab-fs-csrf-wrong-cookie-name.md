---
kind: lab
id_key: production-debugging/lab-fs-csrf-wrong-cookie-name
course: production-debugging
section: fullstack-sessions-cors
section_title: "Sessions, cookies and CORS"
section_position: 18
section_group: "Fullstack"
title: "Lab: Saving the profile fails with \"The request could not be verified"
position: 5
estimated_minutes: 30
source:
    - docs/debug-labs.md
max_duration: 90
recipe: ../recipes/fs-csrf-wrong-cookie-name.yaml
---

Reported by a customer: "Saving the profile fails with "The request could not be verified". Reproduce it in the running shop, find where the browser and the API disagree, and fix it at the source.
