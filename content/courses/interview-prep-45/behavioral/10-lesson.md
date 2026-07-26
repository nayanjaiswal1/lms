---
kind: lesson
id_key: interview-prep-45/day-10-behavioral
course: interview-prep-45
section: behavioral
section_title: "Behavioral"
section_position: 5
title: "Failure and Learning Story"
position: 10
estimated_minutes: 15
source:
    - 45-day-interview-roadmap.md
---
## Why interviewers ask this

This is not the same question as Day 5's production failure. That story tests incident response under pressure. This one tests something slower: **judgment**. Interviewers want a mistake where the failure was a call you made — a wrong estimate, a wrong technical bet, a wrong read on priorities — and, more importantly, proof that you changed how you operate afterward. Candidates who can't name a real mistake read as either dishonest or lacking self-awareness.

## The framework: STAR, weighted on the "what changed after"

- **Situation** — the decision or judgment call, and the context that made it reasonable at the time.
- **Task** — what you were trying to achieve.
- **Action** — what you actually did, including the flawed reasoning — don't hide the mistake, name it.
- **Result** — the consequence, and critically, the concrete change to how you work now, not a vague lesson.

The failure needs to be real enough that it stung, but not so catastrophic that it makes the interviewer question your judgment overall. A missed estimate, a skipped test, a premature optimization, a feature built without validating the need — these are the right size.

## Worked example

> **Situation**: "Early in a project, I decided to build a custom caching layer for a search endpoint because I assumed Redis' built-in expiry wouldn't give us the invalidation granularity we needed. **Task**: I was optimizing for search latency, which was a real problem — P95 was around 800ms. **Action**: I spent about a week and a half building a custom cache with dependency tracking so specific keys could be invalidated when underlying data changed. It worked, but it was complex enough that I was the only one on the team who could safely modify it, and a month later a teammate introduced a bug in it because he didn't understand the invalidation graph. **Result**: We ended up ripping it out and replacing it with plain Redis TTLs plus a slightly more aggressive expiry window, which got us 90% of the latency win with a tenth of the complexity — in hindsight, I never validated that the extra 10% was worth the maintenance cost. Since then, I default to the boring solution first and only reach for something custom after I can point to a concrete case the boring solution fails on, not a hypothetical one."

The change described at the end — "default to boring, prove the need before building custom" — is a real, checkable behavior shift, not a platitude.

## Your template

```
Situation: [the decision, and why it seemed reasonable at the time]
Task: [what you were trying to achieve]
Action: [what you did — including the flawed reasoning, stated plainly]
Result: [the consequence] + [the specific way you work differently now]
```

## Do / Don't

| Do | Don't |
|---|---|
| Name the mistake plainly, no hedging | Pick a "mistake" that's actually a humblebrag |
| Pick something sized like a real misjudgment | Pick something career-ending or trivially small |
| End with a concrete behavior change | End with "I learned to be more careful" |
