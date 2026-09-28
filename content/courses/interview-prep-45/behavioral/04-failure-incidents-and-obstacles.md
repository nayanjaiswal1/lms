---
kind: lesson
id_key: interview-prep-45/day-05-behavioral
course: interview-prep-45
section: behavioral
section_title: "Behavioral & Interview Day"
section_position: 13
title: "Failures, Incidents, and Obstacles"
position: 4
estimated_minutes: 40
source:
    - 45-day-interview-roadmap.md
---

## What the interviewer is really checking

Every engineer breaks production eventually, and every engineer makes a call that turns out wrong. Interviewers asking about failure aren't screening for people who've never caused a problem; that person either hasn't shipped much or is lying. They're screening for how you behave once things go wrong, and whether you own mistakes cleanly instead of reaching for an excuse. Your reaction to failure tells them more than your reaction to success ever could.

## Three questions that sound alike but aren't

"Tell me about a mistake" can mean three different things, and each one is checking something different:

| Question | What it's really testing |
|---|---|
| "A time something broke in production" | How you behave under pressure during an active incident |
| "A time you made a bad call" | Judgment: a wrong estimate or technical bet, and whether you changed how you work afterward |
| "The hardest technical problem you've solved" | Whether you can push through a genuinely hard problem and explain your process clearly |

Picking the wrong shape for the wrong question is a common mistake: an incident story needs mitigate-first instincts, a judgment story needs an honest account of flawed reasoning, and a hard-problem story needs the dead ends you ran into, not just the answer.

> **Remember:** an incident tests pressure, a bad call tests judgment, a hard bug tests persistence. Match the story to the question.

```knowledge-check
{ "questions": [
    { "id": "ip45-beh-04-three-q1", "type": "mcq",
      "prompt": "An interviewer asks \"tell me about the hardest technical problem you've solved.\" What should the Action section emphasize?",
      "options": [
        {"id":"a","text":"Only the final, correct solution, to keep the story tight"},
        {"id":"b","text":"The wrong theories you ruled out along the way, since those are what make the difficulty credible"},
        {"id":"c","text":"How quickly you solved it compared to a teammate"},
        {"id":"d","text":"Why the problem wasn't really your responsibility"}
      ],
      "correct": "b",
      "explanation": "A story where the first guess is correct doesn't read as hard. The dead ends prove the problem was genuinely difficult and show how you actually debug." }
] }
```

## The production incident: mitigate first, diagnose second

```
Situation: [what broke, how you found out (paged? user report? monitoring?), and the severity]
Task: [your specific role: did you cause it, fix it, or both?]
Action: [mitigate first] → [diagnose] → [fix] → [communicate]
Result: [outcome] + [root cause] + [the systemic change made afterward]
```

The trap to avoid: making a teammate, a tool, or "the deploy pipeline" the subject of the story. Even when a shared system was the proximate cause, talk about your role in the response and the fix, not who's at fault.

## Worked example: the Tuesday config change

> **Situation**: "I pushed a config change on a Tuesday afternoon that I believed was a no-op: it was meant to add a new feature flag, defaulted off. Fifteen minutes later we got paged for elevated 500 errors on the checkout API, about 3% of requests. **Task**: I was the one who shipped the change, so I owned the response. **Action**: I rolled back the deploy immediately rather than trying to root-cause it live. That's rule one: stop the bleeding before you investigate. Once error rates recovered, I posted a summary in the incident channel with what I'd rolled back and a rough timeline, then dug into logs and found the flag's default value was being read from a config struct with a stale field from an earlier refactor, so "off" was actually evaluating as "on" for about 3% of traffic on a specific code path. **Result**: I fixed the config bug, added a unit test asserting default flag values match their intended state, and proposed a rule we adopted: any new flag ships behind a canary at 1% of traffic for 30 minutes before a full rollout. We've caught two similar issues at the canary stage since."

Rollback first, root cause second, systemic fix third. That order is what interviewers are listening for.

> **Remember:** stop the bleeding before you investigate. Root cause can wait a few minutes; a growing error rate can't.

```knowledge-check
{ "questions": [
    { "id": "ip45-beh-04-incident-q1", "type": "mcq",
      "prompt": "During a live incident you're responsible for, what should generally come first?",
      "options": [
        {"id":"a","text":"A full root-cause investigation, so the fix addresses the real problem"},
        {"id":"b","text":"Mitigating the impact (such as a rollback), then diagnosing once the bleeding has stopped"},
        {"id":"c","text":"Writing the postmortem document"},
        {"id":"d","text":"Waiting for a manager's approval before taking any action"}
      ],
      "correct": "b",
      "explanation": "Interviewers specifically listen for a mitigate-first instinct. Debugging live in production while errors keep climbing is the wrong order, even if it eventually finds the same root cause." }
] }
```

## The judgment-call mistake: name the flawed reasoning, show the change

```
Situation: [the decision, and why it seemed reasonable at the time]
Task: [what you were trying to achieve]
Action: [what you did, including the flawed reasoning, stated plainly]
Result: [the consequence] + [the specific way you work differently now]
```

The failure needs to be real enough that it stung, but not so large that it makes the interviewer question your judgment overall. A missed estimate, a skipped test, a premature optimization, a feature built without checking whether anyone needed it: these are the right size. Name the mistake plainly. Don't hide it, and don't end with a vague "I learned to be more careful."

## Worked example: the custom cache that wasn't worth it

> **Situation**: "Early in a project, I built a custom caching layer for a search endpoint because I assumed Redis's built-in expiry wouldn't give us the invalidation granularity we needed. **Task**: I was optimizing for search latency, a real problem: P95 was around 800 milliseconds. **Action**: I spent about a week and a half building a custom cache with dependency tracking, so specific keys could be invalidated when underlying data changed. It worked, but it was complex enough that I was the only one who could safely modify it, and a month later a teammate introduced a bug in it because he didn't understand the invalidation graph. **Result**: we ripped it out and replaced it with plain Redis expiry plus a slightly more aggressive window, which got 90% of the latency win with a tenth of the complexity. I never validated that the extra 10% was worth the maintenance cost. Since then, I default to the boring solution first and only reach for something custom after I can point to a concrete case the boring solution actually fails on, not a hypothetical one."

The behavior change at the end, defaulting to boring and proving the need before building custom, is a checkable habit, not a platitude.

> **Remember:** end a mistake story with a specific habit you changed, not "I learned to be more careful."

```knowledge-check
{ "questions": [
    { "id": "ip45-beh-04-judgment-q1", "type": "mcq",
      "prompt": "Which Result section is stronger for a judgment-call mistake story?",
      "options": [
        {"id":"a","text":"\"I learned to be more careful going forward\""},
        {"id":"b","text":"\"Since then, I default to the boring solution first and only build something custom once I can point to a concrete case the simple version fails on\""},
        {"id":"c","text":"\"It wasn't really my fault, the requirements were unclear\""},
        {"id":"d","text":"\"I never made that mistake again\" with no further detail"}
      ],
      "correct": "b",
      "explanation": "A specific, checkable habit shows real behavior change. \"More careful\" is vague enough to mean nothing." }
] }
```

## The technical obstacle: keep the dead ends in

```
Situation: [the technical problem, specific enough to be credible]
Task: [what you were responsible for delivering]
Action: [theory 1, ruled out] → [theory 2, ruled out] → [what actually found the root cause]
Result: [the fix] + [what changed in how you approach similar problems]
```

Most candidates under-explain this section by skipping straight to the answer. The wrong theories are what make the story credible: a problem where your first guess is correct doesn't read as hard.

## Worked example: the sharding bug that took two days

> **Situation**: "I was migrating a service from a single Postgres instance to a sharded setup, and after cutover, a specific class of queries that joined across two tables started timing out intermittently, about 1 in 200 requests. **Task**: I owned the migration, and it was blocking the rest of the team from shipping features against the new schema. **Action**: my first theory was connection pool exhaustion, so I bumped the pool size. No change. Then I suspected lock contention and added query logging. Still nothing obvious. It took two days of adding timing instrumentation around every step before I found it: the shard-routing layer was occasionally computing the wrong shard key for a join when a row had recently moved during a rebalance, causing a cross-shard fallback down a much slower query path. **Result**: I fixed the routing layer to check for in-flight rebalances before computing shard keys, added an alert on the cross-shard fallback rate, and documented the rebalance race condition for anyone building sharded features on that system. It's the reason I now always add fallback-path monitoring for any routing logic, even when the fallback "shouldn't" trigger often."

## Common mistakes

- Blaming a tool, a teammate, or the deploy pipeline instead of describing your own role in the response.
- Skipping straight to the fix in a hard-problem story and leaving out the dead ends.
- Picking a "mistake" so small it reads as a humblebrag, or so large it raises doubts about your judgment overall.
- Ending any of these stories with a vague lesson instead of a concrete, checkable change.

> **Remember:** the systemic fix at the end of an incident story matters more than the fix itself. It's the proof this class of bug is now harder to repeat.
