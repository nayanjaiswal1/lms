---
kind: lesson
id_key: interview-prep-45/day-05-behavioral
course: interview-prep-45
section: behavioral
section_title: "Behavioral"
section_position: 5
title: "Production Failure Story"
position: 5
estimated_minutes: 15
source:
    - 45-day-interview-roadmap.md
---
## Why interviewers ask this

Every engineer breaks production eventually. Interviewers asking this aren't screening for people who've never caused an incident (that person either hasn't shipped much or is lying). They're screening for how you behave under pressure and whether you own mistakes cleanly or reach for excuses. Your reaction to failure tells them more than your reaction to success.

## The framework: STAR, with a blameless-postmortem lens

Use the same STAR shape from Day 4, but weight it specifically:

- **Situation**: what broke, how you found out (paged? user report? monitoring?), and the severity.
- **Task**: your specific role in the response. Were you the one who caused it, the one who fixed it, or both?
- **Action**: the sequence: diagnose, mitigate, fix, communicate. Interviewers care about your process under pressure as much as the fix itself.
- **Result**: the outcome, the root cause, and, critically, the systemic change that makes it harder for this class of bug to happen again.

The trap to avoid: making a teammate, a tool, or "the deploy pipeline" the subject of the story. Even if a shared system was the proximate cause, talk about your role in the response and the fix, not who's at fault.

## Worked example

> **Situation**: "I pushed a config change on a Tuesday afternoon that I believed was a no-op. It was meant to just add a new feature flag, defaulted off. Fifteen minutes later we started getting paged for elevated 500s on the checkout API, about 3% of requests. **Task**: I was the one who shipped the change, so I owned the response. **Action**: I first rolled back the deploy immediately rather than trying to root-cause live. That's rule one: stop the bleeding before you investigate. Once error rates recovered, I posted a summary in the incident channel with what I'd rolled back and a rough timeline, then dug into logs and found the flag's default value was being read from a config struct that had a stale field from an earlier refactor, so 'off' was actually evaluating as 'on' for about 3% of traffic that hit a specific code path. **Result**: I fixed the config bug, added a unit test asserting default flag values match their intended state, and proposed, and we adopted, a rule that any new flag ships behind a canary at 1% traffic for 30 minutes before full rollout. We've caught two similar issues at the canary stage since."

Rollback first, root-cause second, systemic fix third. That order matters to interviewers.

## Your template

```
Situation: [what broke, how you found out, severity]
Task: [your specific role: did you cause it, fix it, or both]
Action: [mitigate first] → [diagnose] → [fix] → [communicate]
Result: [outcome] + [root cause] + [systemic change made afterward]
```

## Do / Don't

| Do | Don't |
|---|---|
| Say "I caused this" plainly if you did | Deflect to a teammate or a flaky tool |
| Show mitigate-first, diagnose-second instinct | Describe debugging live in prod as the first move |
| End with a concrete systemic fix | End with "and I was more careful after that" |
| Quantify blast radius and recovery time | Leave severity vague |
