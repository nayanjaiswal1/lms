---
kind: lesson
id_key: interview-prep-45/day-04-behavioral
course: interview-prep-45
section: behavioral
section_title: "Behavioral"
section_position: 5
title: "Conflict Resolution Story"
position: 4
estimated_minutes: 15
source:
    - 45-day-interview-roadmap.md
---
## Why interviewers ask this

"Tell me about a disagreement" is checking one thing: can you hold a technical position under pushback without becoming either a pushover or a jerk about it. Teams don't fail because engineers disagree — they fail when disagreement turns into politics, silent resentment, or someone getting steamrolled. Interviewers want evidence you can disagree and still ship.

## The framework: STAR

STAR is the default structure for every "tell me about a time" question. Learn it once here, reuse it for the rest of the course.

- **Situation** — 1-2 sentences of context. Enough to understand the stakes, no more.
- **Task** — what you specifically were responsible for or trying to achieve.
- **Action** — what *you* did, step by step. This is 60% of the answer. Use "I," not "we."
- **Result** — the outcome, quantified if possible, plus what you'd do differently.

For a conflict story specifically, the Action section needs to show you argued with **data and reasoning**, not authority or volume, and that you were willing to be wrong.

## Worked example

> **Situation**: "On my last team, a senior engineer wanted to introduce a new message queue for a feature that already had a working synchronous API call between two services. **Task**: I was the one who'd own the maintenance of whichever solution we picked, so I pushed back and needed to either convince him or be convinced. **Action**: Instead of arguing in the PR thread, I asked for 30 minutes to whiteboard both approaches. I laid out the actual failure modes we'd seen in production over the last quarter — none of them were things a queue would have fixed — and I asked him what specific problem he was trying to prevent. It turned out he was worried about a retry storm scenario that had bitten him at a previous company, which was a fair concern, just not one our traffic pattern matched. We agreed to keep the synchronous call but add a circuit breaker with backoff, which addressed his concern with a fraction of the complexity. **Result**: We shipped the circuit breaker in three days instead of the two-week queue migration, and it's held up through two real incidents since without a retry storm. He and I ended up pairing regularly after that — the disagreement actually built trust instead of costing it."

Notice there's no villain. The other engineer's concern was legitimate; the story is about surfacing the real problem, not "winning."

## Your template

```
Situation: [1-2 sentences of context on the disagreement]
Task: [what you were responsible for deciding or delivering]
Action: [how you made your case — data, questions, compromise — step by step]
Result: [outcome, quantified] + [what you'd do differently, if anything]
```

## Do / Don't

| Do | Don't |
|---|---|
| Show you understood the other person's concern | Paint the other person as simply wrong |
| Use data or a concrete example to make your case | Rely on "I've done this before, trust me" |
| Land on a resolution, even a compromise | Leave the ending ambiguous or unresolved |
| Say "I" for your actions | Hide behind "we decided" the whole time |
