---
kind: lab
id_key: production-debugging/lab-fs-api-search-query-not-encoded
course: production-debugging
section: fullstack-api-contract
section_title: "The API contract"
section_position: 19
section_group: "Fullstack"
title: "Lab: Searching for \"R&D Kit\" lists everything containing an R"
position: 3
estimated_minutes: 30
source:
    - docs/debug-labs.md
max_duration: 90
recipe: ../recipes/fs-search-query-not-encoded.yaml
---

Reported by a customer: "Searching for "R&D Kit" lists everything containing an R". Reproduce it in the running shop, find where the browser and the API disagree, and fix it at the source.
