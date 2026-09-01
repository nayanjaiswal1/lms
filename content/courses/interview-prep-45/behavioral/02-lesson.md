---
kind: lesson
id_key: interview-prep-45/day-02-behavioral
course: interview-prep-45
section: behavioral
section_title: "Behavioral"
section_position: 5
title: "Project Deep Dive - Project 1"
position: 2
estimated_minutes: 15
source:
    - 45-day-interview-roadmap.md
---
## Why interviewers ask this

Project deep dives are where interviewers check whether your resume bullets are real. They want to watch you reason about trade-offs, articulate decisions, and own outcomes rather than recite what the code did. This is also where seniority gets read: junior candidates describe what they built; senior candidates explain why they built it that way and what they'd do differently now.

## The framework: PSICD

STAR is built for a single moment in time. A project deep dive spans weeks or months and needs to survive ten minutes of follow-up questions, so use a wider frame:

- **Problem**: what was broken or missing, described in user and business terms first, technical terms second.
- **Solution**: the system you actually built, at a level of detail a competent engineer outside your team could follow.
- **Impact**: what changed, quantified. Latency, cost, error rate, adoption, revenue: pick what's real.
- **Challenges**: the hardest part, and specifically why it was hard. "There was a lot to do" doesn't count.
- **Decisions**: one real trade-off you made, the alternative you rejected, and why.

Interviewers will drill into whichever piece sounds thinnest, so don't pad the parts you can't defend.

## Worked example

> "**Problem**: Our checkout flow was losing about 8% of orders to timeout errors during peak traffic because the inventory service did a synchronous call to three downstream systems per item. **Solution**: I redesigned it around an async reservation queue. Checkout would grab a soft hold on inventory immediately and confirm it in the background, with a 2-second SLA before falling back to the old synchronous path. **Impact**: Timeout-related checkout failures dropped from 8% to under 0.5%, and P99 checkout latency went from 4.2s to 600ms. **Challenges**: The hardest part was handling the fallback correctly. If the async confirmation failed, we had a small window where we could oversell inventory, so I had to add a reconciliation job that ran every minute to catch and reverse those cases. **Decisions**: I considered adding a full event-sourced inventory system instead, which would have solved the overselling problem more elegantly, but it was a 6-week rewrite versus a 1-week patch, and the business needed the fix before the holiday traffic spike. So I shipped the reconciliation job and left a design doc for the bigger rework."

Five sentences, one per section, delivered in under 5 minutes with room for follow-ups.

## Your template

```
Problem: [what was broken, in user/business terms]

Solution: [the system you built, one level of technical detail]

Impact: [metric before] → [metric after]

Challenges: [the hardest specific part, and why]

Decisions: [trade-off made] vs [alternative rejected], because [reason]
```

## Do / Don't

| Do | Don't |
|---|---|
| Pick your most technically complex project | Pick the project that's easiest to explain but shallow |
| Quantify impact, even roughly | Say "it made things a lot faster" |
| Name one real trade-off you made | Pretend the design was obviously correct from day one |
| Practice the 5-minute version out loud | Only ever say it in your head |
