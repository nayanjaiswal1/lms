---
kind: lesson
id_key: interview-prep-45/day-19-behavioral
course: interview-prep-45
section: behavioral
section_title: "Behavioral"
section_position: 5
title: "Success Story"
position: 19
estimated_minutes: 15
source:
    - 45-day-interview-roadmap.md
---
## Why interviewers ask this

"Biggest achievement" is checking scale of impact and whether you can talk about your own work without either false modesty or team-credit-stealing. It also calibrates level: the size of what you consider your biggest achievement tells the interviewer roughly where you're operating.

## The framework: STAR, weighted on scope and recognition

- **Situation**: the starting state, so the achievement has a baseline to be measured against.
- **Task**: your specific role, especially if others were involved.
- **Action**: what you actually did, with enough detail to show it was hard.
- **Result**: the quantified impact, plus any recognition (promotion, adoption beyond your team, a metric that stuck) that proves it wasn't just self-assessed.

Pick something with a number attached, even an approximate one. "It went well" gives an interviewer nothing to calibrate against.

## Worked example

> **Situation**: "Our checkout flow had a 12% cart-abandonment rate at the payment step specifically, well above the rest of the funnel, and nobody had root-caused why. **Task**: I volunteered to own an investigation alongside my regular sprint work, since I'd noticed the pattern in an analytics dashboard nobody was checking closely. **Action**: I instrumented the payment step with more granular event tracking, found that international cards were failing silently on a currency-formatting bug, and separately found that the payment form was re-rendering and losing input on a specific mobile browser. I fixed both, and pushed for a change in how we monitored payment-step drop-off going forward, since the existing dashboard hadn't surfaced either issue. **Result**: Cart abandonment at the payment step dropped from 12% to 4% over the next month, which the finance team estimated at roughly $40k/month in recovered revenue. It got called out in the quarterly all-hands as one of the highest-ROI fixes that quarter, and led to me being asked to own payments reliability going forward."

Baseline number, root cause, fixed number, and third-party recognition: that combination is what makes an achievement story land.

## Your template

```
Situation: [starting state, with a baseline number]
Task: [your specific role]
Action: [what you actually did: be specific about the mechanism]
Result: [quantified impact] + [recognition: promotion, adoption, praise, ongoing ownership]
```

## Do / Don't

| Do | Don't |
|---|---|
| Start with a baseline number to measure against | Say "it went really well" with no metric |
| Give yourself clear individual credit if it's your story | Say "we" for every sentence when it was mostly you |
| Include external recognition if there was any | Rely only on your own assessment of impact |
