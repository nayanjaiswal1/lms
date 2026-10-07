---
kind: lab
id_key: production-debugging/lab-re-api-http-error-treated-as-success
course: production-debugging
section: react-api-config
section_title: "API and configuration"
section_position: 17
section_group: "React"
title: "Lab: The UI says Saved while the server was down"
position: 2
estimated_minutes: 30
source:
    - docs/debug-labs.md
max_duration: 90
recipe: ../recipes/re-api-http-error-treated-as-success.yaml
---

During an outage users saw success messages for requests that failed. Trace how the client decides a response is an error.
