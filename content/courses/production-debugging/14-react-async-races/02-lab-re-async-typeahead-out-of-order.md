---
kind: lab
id_key: production-debugging/lab-re-async-typeahead-out-of-order
course: production-debugging
section: react-async-races
section_title: "Async and races"
section_position: 14
section_group: "React"
title: "Lab: Customer search shows results for an older query"
position: 2
estimated_minutes: 35
source:
    - docs/debug-labs.md
max_duration: 90
hint_penalty_pct: 10
recipe: ../recipes/re-async-typeahead-out-of-order.yaml
---

Typing quickly in customer search sometimes ends on results for an earlier term. Reproduce the ordering and make the latest query win.
