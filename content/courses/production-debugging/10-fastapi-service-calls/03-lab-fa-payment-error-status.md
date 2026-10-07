---
kind: lab
id_key: production-debugging/lab-fa-payment-error-status
course: production-debugging
section: fastapi-service-calls
section_title: "Service calls and errors"
section_position: 10
section_group: "FastAPI"
title: "Lab: Customers cannot pay but the dashboards show no errors"
position: 3
estimated_minutes: 30
source:
    - docs/debug-labs.md
max_duration: 90
recipe: ../recipes/fa-payment-error-status.yaml
---

Support is flooded with failed payments while the error-rate dashboard shows zero. Find out what the API actually answers when the provider fails and fix the contract.
