---
kind: lab
id_key: production-debugging/lab-fa-chain-double-charge-freeze
course: production-debugging
section: fastapi-config-security
section_title: "Configuration and security"
section_position: 12
section_group: "FastAPI"
title: "Expert lab: Double charges, then a frozen API, then a kill switch that does nothing"
position: 4
estimated_minutes: 120
source:
    - docs/debug-labs.md
max_duration: 180
hint_penalty_pct: 10
recipe: ../recipes/fa-chain-double-charge-freeze.yaml
---

Expert level: three production problems in one payments incident, and each one hides the next. Customers are charged twice when the provider has a bad minute. Once you stop that, the whole API freezes after a handful of failed payments. Once the API stays up, the kill switch you reach for to stop payments during the incident does nothing. Fix each root cause where it belongs, never a symptom, and prove every fix with a test that fails on the broken code. The provider is flaky by design (about half of its responses are errors after the charge is recorded), so expect every attempt to behave differently.
