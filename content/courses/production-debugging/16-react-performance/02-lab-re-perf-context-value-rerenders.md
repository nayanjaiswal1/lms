---
kind: lab
id_key: production-debugging/lab-re-perf-context-value-rerenders
course: production-debugging
section: react-performance
section_title: "Performance"
section_position: 16
section_group: "React"
title: "Lab: Typing in the quick filter makes every page re-render"
position: 2
estimated_minutes: 35
source:
    - docs/debug-labs.md
max_duration: 90
recipe: ../recipes/re-perf-context-value-rerenders.yaml
---

The app lags while typing in the quick filter. Measure the renders and stop the ones that have no reason to happen.
