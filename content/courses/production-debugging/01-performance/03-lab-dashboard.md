---
kind: lab
id_key: production-debugging/lab-dj-perf-dashboard
course: production-debugging
section: django-performance
section_title: "Performance"
section_position: 1
section_group: "Django"
title: "Lab: The staff dashboard hits the database too often"
position: 3
estimated_minutes: 40
source:
    - docs/debug-labs.md
max_duration: 90
recipe: ../recipes/dj-perf-dashboard.yaml
---

The operations team sees the store dashboard at the top of the query-volume graphs. The numbers on the page are right; it is just doing more work than it should. Find which lines evaluate the same data more than once, fix them, and lock the query count in with a test.
