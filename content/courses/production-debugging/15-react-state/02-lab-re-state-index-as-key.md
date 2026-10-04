---
kind: lab
id_key: production-debugging/lab-re-state-index-as-key
course: production-debugging
section: react-state
section_title: "State and identity"
section_position: 15
section_group: "React"
title: "Lab: Deleting a note makes the next note show the wrong text"
position: 2
estimated_minutes: 25
source:
    - docs/debug-labs.md
max_duration: 90
recipe: ../recipes/re-state-index-as-key.yaml
---

After deleting a note, the one below inherits the text being edited. Find what React matches the rows by.
