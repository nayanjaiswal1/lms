---
kind: lab
id_key: production-debugging/lab-fa-wallet-lost-update
course: production-debugging
section: fastapi-async
section_title: "Async and concurrency"
section_position: 9
section_group: "FastAPI"
title: "Lab: Store credit goes missing under load"
position: 3
estimated_minutes: 50
source:
    - docs/debug-labs.md
max_duration: 90
recipe: ../recipes/fa-wallet-lost-update.yaml
---

After a promotion some wallet balances do not add up to their ledger. It only happens when several credits arrive at once. Reproduce the race, fix it where it belongs, and prove it with a concurrent test.
