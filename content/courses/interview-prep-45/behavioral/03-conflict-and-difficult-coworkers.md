---
kind: lesson
id_key: interview-prep-45/day-04-behavioral
course: interview-prep-45
section: behavioral
section_title: "Behavioral & Interview Day"
section_position: 13
title: "Conflict and Difficult Coworkers"
position: 3
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---

## What the interviewer is really checking

"Tell me about a disagreement" is checking one thing: can you hold a technical position under pushback without turning into either a pushover or a bulldozer. Teams rarely fail because two engineers disagree. They fail when a disagreement turns into politics, silent resentment, or one person getting steamrolled. The interviewer wants evidence you can disagree and still ship.

A related but different question, about a difficult coworker, isn't about one disagreement. It's about ongoing friction: someone dismissive, someone who takes credit, someone who keeps missing commitments. Here the interviewer wants to know you can stay professional and keep shipping when you can't just win the argument with better data, because there isn't one clean argument to win.

## Question variants you might hear

- "Tell me about a time you disagreed with a teammate or your manager."
- "A time you pushed back on an idea you thought was wrong."
- "Tell me about a difficult coworker."
- "How do you handle someone who doesn't pull their weight, or takes credit for your work?"

## The STAR skeleton for a conflict story

```
Situation: [1-2 sentences on the disagreement and what was at stake]
Task: [what you were responsible for deciding or delivering]
Action: [how you made your case: data, questions, a compromise, step by step]
Result: [outcome, quantified] + [what you'd do differently, if anything]
```

For a conflict story specifically, the Action needs to show you argued with data and reasoning, not authority or volume, and that you were genuinely willing to be wrong. Weak answers avoid naming the actual disagreement, or paint the other person as simply mistaken. Strong answers show you understood the other side's position before resolving it.

> **Remember:** the goal of a conflict story is showing you surfaced the real problem, not that you won.

```knowledge-check
{ "questions": [
    { "id": "ip45-beh-03-skeleton-q1", "type": "mcq",
      "prompt": "What separates a strong conflict story from a weak one, in the Action section specifically?",
      "options": [
        {"id":"a","text":"A strong story shows you convinced the other person using seniority or persistence"},
        {"id":"b","text":"A strong story shows you understood the other person's concern and argued with data, not authority"},
        {"id":"c","text":"A strong story avoids naming what the disagreement was actually about"},
        {"id":"d","text":"A strong story ends with the other person clearly being wrong"}
      ],
      "correct": "b",
      "explanation": "Interviewers are checking whether you can hold a position with evidence and stay open to being wrong, not whether you can out-argue someone." }
] }
```

## Worked example: disagreeing with a senior engineer

> **Situation**: "On my last team, a senior engineer wanted to introduce a new message queue for a feature that already had a working, synchronous API call between two services. **Task**: I was the one who'd own the maintenance of whichever solution we picked, so I pushed back and needed to either convince him or be convinced. **Action**: instead of arguing in the pull request thread, I asked for 30 minutes to whiteboard both approaches. I laid out the actual failure modes we'd seen in production over the last quarter, none of which a queue would have fixed, and I asked what specific problem he was trying to prevent. It turned out he was worried about a retry storm that had bitten him at a previous company, a fair concern, just not one that matched our traffic pattern. We agreed to keep the synchronous call but add a circuit breaker with backoff, which addressed his concern with a fraction of the complexity. **Result**: we shipped the circuit breaker in three days instead of the two-week queue migration, and it's held up through two real incidents since without a retry storm. He and I ended up pairing regularly after that: the disagreement built trust instead of costing it."

There's no villain in this story. The other engineer's concern was real; the story is about surfacing that real concern, not about winning a debate.

## Difficult coworkers are a different problem: friction, not one decision

A difficult-coworker story isn't a single disagreement, it's a pattern: someone dismissive, someone who's repeatedly unreliable, someone who takes credit. The right move is usually a direct, private conversation first, escalation only if that fails, and continuing to collaborate professionally regardless of how you feel about the person. Not every one of these stories ends in a full turnaround, and pretending it does reads as dishonest.

```
Situation: [the specific behavior pattern, described factually, not as a character attack]
Task: [how their behavior was actually affecting your work or the team's]
Action: [private conversation first] → [what you learned or proposed] → [escalation only if needed]
Result: [the outcome, even if only partial]
```

> **Remember:** describe the behavior, not the person's character. Interviewers are evaluating your reaction, not judging the coworker.

```knowledge-check
{ "questions": [
    { "id": "ip45-beh-03-difficult-q1", "type": "mcq",
      "prompt": "A candidate's difficult-coworker story ends with \"and after that he became a totally different person, we're best friends now.\" Why might this read as a weak answer?",
      "options": [
        {"id":"a","text":"It's too short"},
        {"id":"b","text":"A perfectly tidy, full turnaround is uncommon in real workplace friction, and claiming one can read as fabricated rather than honest"},
        {"id":"c","text":"Difficult-coworker stories should never end on a positive note"},
        {"id":"d","text":"It uses too much dialogue"}
      ],
      "correct": "b",
      "explanation": "Real friction rarely resolves into a complete transformation. An honest \"I fixed the part that was mine to fix\" is more credible than a fabricated happy ending." }
] }
```

## Worked example: the coworker who kept missing commitments

> **Situation**: "I worked with an engineer on another team who'd regularly commit to API contract changes in meetings, then not follow through, which broke my team's integration work without warning at least three times over two months. **Task**: I needed the integration to actually stay stable, and escalating right away felt like it would burn a relationship I'd need long-term. **Action**: I asked him directly, one-on-one, whether the commitments in meetings were realistic or if something upstream was blocking him. It turned out his team was chronically understaffed and he was over-committing under pressure from his own manager. I suggested we move from verbal commitments to a shared doc with real dates, so at minimum I'd get advance warning instead of a broken integration. **Result**: the surprise breakages stopped. He still occasionally missed dates, but now I had lead time to adjust instead of finding out from a failing test. I didn't fix his team's staffing problem, but I fixed the part of it that was actually my problem to fix."

The honest "I didn't fix everything, but I fixed my piece" ending is more credible than a fabricated full resolution.

## Common mistakes

- Painting the other person as simply wrong instead of showing you understood their concern.
- Hiding behind "we decided" instead of naming what you personally did.
- Jumping straight to escalation instead of a direct conversation first.
- Inventing a perfectly tidy ending for a story that was actually messier in real life.

> **Remember:** a conflict story with no compromise and no respect for the other side reads as a warning sign, not a win.
