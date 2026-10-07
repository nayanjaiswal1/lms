---
kind: lab
id_key: production-debugging/lab-re-perf-resize-listener-leak
course: production-debugging
section: react-performance
section_title: "Performance"
section_position: 16
section_group: "React"
title: "Lab: Memory and CPU grow every time Orders is opened"
position: 3
estimated_minutes: 35
source:
    - docs/debug-labs.md
max_duration: 90
recipe: ../recipes/re-perf-resize-listener-leak.yaml
---

A long session slows down after repeated visits to the Orders page. Find what each visit leaves behind.
