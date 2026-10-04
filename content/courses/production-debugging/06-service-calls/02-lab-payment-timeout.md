---
kind: lab
id_key: production-debugging/lab-dj-payment-timeout
course: production-debugging
section: django-service-calls
section_title: "Calls to other services"
section_position: 6
section_group: "Django"
title: "Lab: Checkout hangs when the payments provider is slow"
position: 2
estimated_minutes: 40
source:
    - docs/debug-labs.md
max_duration: 90
recipe: ../recipes/dj-payment-timeout.yaml
---

During provider trouble, checkout requests piled up and the whole site slowed down. Find the call that can wait forever and give it a sensible failure mode.
