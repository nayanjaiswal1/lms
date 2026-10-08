---
kind: lab
id_key: production-debugging/lab-re-hooks-stale-interval-closure
course: production-debugging
section: react-hooks
section_title: "React hooks"
section_position: 13
section_group: "React"
title: "Lab: The updated badge never gets past 1"
position: 2
estimated_minutes: 25
source:
    - docs/debug-labs.md
max_duration: 90
hint_penalty_pct: 10
recipe: ../recipes/re-hooks-stale-interval-closure.yaml
---

The refresh badge on the orders page counts seconds but freezes after the first tick. Find why the timer keeps reading an old value and fix it.
