---
kind: lesson
id_key: interview-prep-45/day-03-behavioral
course: interview-prep-45
section: behavioral
section_title: "Behavioral"
section_position: 5
title: "Project Deep Dive - Project 2"
position: 3
estimated_minutes: 15
source:
    - 45-day-interview-roadmap.md
---
## Why interviewers ask this

One deep dive proves you can build. A second, different deep dive proves you're not a one-trick pony. Interviewers who ask "tell me about another project" are checking for range: can you also lead, handle ambiguity, or work cross-functionally, and not only write good code under a well-defined spec.

## The technique: pick for contrast, not for comfort

Yesterday you used PSICD (Problem, Solution, Impact, Challenges, Decisions) on your most technically complex project. Today, apply the same structure to a **second** project, but choose it deliberately to cover a gap Project 1 doesn't:

- If Project 1 showcased deep technical execution, pick a Project 2 that showcases **ambiguity handling** or **cross-team coordination**.
- If Project 1 was a solo build, pick a Project 2 that was a **team effort**, one where your specific contribution needs to be clear.
- If Project 1 was recent, consider a Project 2 that's a couple of years older. It shows growth over time, beyond just your current job.

The goal by the end of Day 3: two stories that, together, cover noticeably different skills. If both stories prove "I can write good backend code," you've wasted one of your two slots.

## Worked example

> "My other project was rebuilding our on-call alerting system, which is a good contrast to my checkout work because it was less about raw technical difficulty and more about getting three teams to agree on ownership. **Problem**: We had 40+ alert rules with no clear owner, so pages went to whoever was on-call regardless of which system was actually failing, and mean time to acknowledge was climbing. **Solution**: I mapped every alert to a specific service owner, built a routing layer on top of our existing paging tool, and ran a two-week trial with the two loudest teams before rolling it out org-wide. **Impact**: MTTA dropped from 14 minutes to under 3, and on-call complaints in our engineering survey dropped noticeably the following quarter. **Challenges**: The hardest part wasn't the code. It was getting a team that didn't want to 'own' a noisy alert to actually take it, which took a few one-on-one conversations and showing them the noise was fixable, not permanent. **Decisions**: I chose to build the routing layer on our existing tool instead of migrating to a new alerting platform, because a platform migration would have taken months of political buy-in I didn't have time for."

Same PSICD skeleton as Day 2, but the weight sits on stakeholder alignment, not architecture.

## Your template

```
Why this project is different from Project 1: [what skill/dimension it adds]

Problem: [what was broken, in user/business terms]
Solution: [what you built or changed]
Impact: [metric before] → [metric after]
Challenges: [the hardest specific part, and why]
Decisions: [trade-off made] vs [alternative rejected], because [reason]
```

## Do / Don't

| Do | Don't |
|---|---|
| Choose a project that covers a different skill than Project 1 | Pick a near-duplicate of yesterday's story |
| Be explicit about your individual contribution on team projects | Say "we" for every sentence and never "I" |
| Keep it to 5 minutes, same as Day 2 | Let it run long because it's a favorite story |
