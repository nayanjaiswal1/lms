---
kind: lesson
id_key: interview-prep-45/day-17-behavioral
course: interview-prep-45
section: behavioral
section_title: "Behavioral"
section_position: 5
title: "Innovation Story"
position: 17
estimated_minutes: 15
source:
    - 45-day-interview-roadmap.md
---
## Why interviewers ask this

This question checks whether you generate improvements without being told to, and whether you can get something adopted, beyond just built. Plenty of candidates have a "cool thing I built" story with no adoption: a script that sat in their own repo that nobody else used. Interviewers are listening specifically for the adoption part.

## The framework: STAR, weighted on adoption

- **Situation**: the inefficiency or gap you noticed that nobody had addressed.
- **Task**: why you decided to build something for it, unprompted.
- **Action**: what you built, and just as important, how you got other people to actually use it.
- **Result**: adoption numbers or behavior change, more than just "it worked for me."

## Worked example

> **Situation**: "Our deploy process required someone to manually check four dashboards before approving a release, and it was taking 15-20 minutes per deploy, several times a day. **Task**: Nobody asked me to fix it, but I was the one doing it most often and it was clearly wasted time. **Action**: I wrote a small Go service that polled those four dashboards' APIs and posted a single pass/fail summary to our deploy Slack channel, with links to the source dashboard for detail. I didn't try to make it mandatory. I just started using it myself and posting the summary before every deploy I ran, so people could see it working. **Result**: Within two weeks, three other engineers had asked me to add them to the notification list, and it became the default first step in our deploy checklist without me having to push for it. Deploy approval time dropped from 15-20 minutes to under 2, across the whole team."

The mechanism for adoption is the same as the leadership story from Day 6: visible usage, not a mandate.

## Your template

```
Situation: [the inefficiency or gap nobody had addressed]
Task: [why you decided to fix it, unprompted]
Action: [what you built] + [how you got others to use it]
Result: [adoption evidence] + [measurable impact]
```

## Do / Don't

| Do | Don't |
|---|---|
| Show real adoption by other people | Stop the story at "I built it" |
| Explain what gap or inefficiency prompted it | Describe innovation for its own sake |
| Quantify the before/after | Leave impact implicit |
