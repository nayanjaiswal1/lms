---
kind: lab
id_key: production-debugging/lab-re-async-optimistic-flag-no-rollback
course: production-debugging
section: react-async-races
section_title: "Async and races"
section_position: 14
section_group: "React"
title: "Lab: An order stays flagged after the server refused it"
position: 3
estimated_minutes: 30
source:
    - docs/debug-labs.md
max_duration: 90
hint_penalty_pct: 10
recipe: ../recipes/re-async-optimistic-flag-no-rollback.yaml
---

When flagging fails the user sees an error but the order keeps its flag. Read the failure path and restore the right state.
