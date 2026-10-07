---
kind: lab
id_key: production-debugging/lab-re-hooks-missing-effect-dependency
course: production-debugging
section: react-hooks
section_title: "React hooks"
section_position: 13
section_group: "React"
title: "Lab: Changing the status filter does not reload orders"
position: 3
estimated_minutes: 30
source:
    - docs/debug-labs.md
max_duration: 90
recipe: ../recipes/re-hooks-missing-effect-dependency.yaml
---

Support reports that picking a status filter leaves the old orders on screen until the page changes. Find what the data effect misses.
