---
kind: lesson
id_key: interview-prep-45/day-18-behavioral
course: interview-prep-45
section: behavioral
section_title: "Behavioral"
section_position: 5
title: "Day 18 — Overcoming Obstacle Story"
position: 18
estimated_minutes: 15
source:
    - 45-day-interview-roadmap.md
---
## Why interviewers ask this

This is the most direct test of technical grit: can you describe getting genuinely stuck and working through it, rather than a problem that was hard for five minutes and then obvious. Interviewers are listening for your debugging process and whether you can explain a hard technical situation clearly under interview pressure.

## The framework: STAR, weighted on the actual struggle

- **Situation** — the technical problem, with enough detail that the difficulty is credible.
- **Task** — what you were responsible for delivering despite the obstacle.
- **Action** — the sequence of things you tried, including the ones that didn't work. This is where most candidates under-explain — the dead ends are what make the story credible.
- **Result** — how you solved it, and what changed in how you approach similar problems now.

## Worked example

> **Situation**: "I was migrating a service from a single Postgres instance to a sharded setup, and after cutover, a specific class of queries that joined across two tables started timing out intermittently — maybe 1 in 200 requests. **Task**: I owned the migration, and it was blocking the rest of the team from shipping features against the new schema. **Action**: My first theory was connection pool exhaustion, so I bumped pool size — no change. Then I suspected lock contention, added query logging — nothing obvious. It took two days of adding timing instrumentation around every step before I found it: the shard-routing layer was occasionally computing the wrong shard key for a join when one of the joined rows had been recently moved during a rebalance, causing a cross-shard fallback that used a much slower query path. **Result**: I fixed the routing layer to check for in-flight rebalances before computing shard keys, added an alert on cross-shard fallback rate, and documented the rebalance race condition for anyone building sharded features on that system. It's the reason I now always add fallback-path monitoring for any routing logic, even if the fallback 'shouldn't' trigger often."

The two wrong theories before the real cause are what make this credible — a story where the first guess is correct reads as too easy.

## Your template

```
Situation: [the technical problem, specific enough to be credible]
Task: [what you were responsible for delivering]
Action: [theory 1, ruled out] → [theory 2, ruled out] → [what actually found the root cause]
Result: [the fix] + [what changed in how you approach similar problems]
```

## Do / Don't

| Do | Don't |
|---|---|
| Include the wrong theories you ruled out | Present the first guess as the correct one |
| Show the specific debugging step that found root cause | Say "after some investigation, I found..." |
| End with a lasting change to your process | End at "and then it worked" |

## Today's checklist
- [ ] Write story about technical challenge you overcame
- [ ] Include: What made it hard, how you solved it
- [ ] Practice: "Tell me about a technical challenge"

**Revision tasks:**
- [ ] Review greedy algorithms
- [ ] Review Kafka
