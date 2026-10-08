---
kind: lab
id_key: production-debugging/lab-fa-client-per-request
course: production-debugging
section: fastapi-latency
section_title: "Latency and slow APIs"
section_position: 21
section_group: "FastAPI"
title: "Lab: A new connection for every charge"
position: 4
estimated_minutes: 40
source:
    - docs/debug-labs.md
max_duration: 90
hint_penalty_pct: 10
recipe: ../recipes/fa-client-per-request.yaml
---

The payments provider sees one new connection per charge and the hosts pile up sockets in TIME_WAIT. Find where connections are thrown away and make charges share one pooled client.
