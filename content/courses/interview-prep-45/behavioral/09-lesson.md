---
kind: lesson
id_key: interview-prep-45/day-09-behavioral
course: interview-prep-45
section: behavioral
section_title: "Behavioral"
section_position: 5
title: "Day 9 — Collaboration Story"
position: 9
estimated_minutes: 15
source:
    - 45-day-interview-roadmap.md
---
## Why interviewers ask this

Engineers who can only communicate with other engineers are a liability past the junior level — most real product work depends on a PM setting scope, a designer defining the experience, or a support lead surfacing what customers actually hit. "Tell me about working with non-engineers" checks whether you can translate technical reality into terms a non-technical stakeholder can act on, and whether you respect their expertise instead of talking down to it.

## The framework: STAR, weighted on translation

Same STAR shape as Day 4. The distinguishing element here is the **Action** — show the specific move you made to bridge the technical and non-technical sides, not just "we talked it through."

- **Situation** — a case where engineering reality and a non-engineer's expectation didn't line up (timeline, scope, or feasibility).
- **Task** — what you were responsible for resolving or communicating.
- **Action** — how you translated the technical trade-off into terms they could actually decide on, and how you incorporated their input back into the technical plan.
- **Result** — the outcome, and evidence the relationship worked, not just the ticket.

## Worked example

> **Situation**: "Our PM wanted a real-time collaborative editing feature shipped in three weeks, based on a competitor's launch. From an engineering standpoint, real-time sync with conflict resolution was a 6-8 week problem, not three. **Task**: I was the tech lead on the feature, so I owned explaining the gap without just saying 'no.' **Action**: Instead of pushing back with jargon about operational transforms and CRDTs, I framed it as two options with a whiteboard: Option A, true real-time collaborative editing, 6-8 weeks; Option B, 'last write wins' with a visible lock indicator so two people can't silently overwrite each other, ships in 10 days and covers the actual complaint we'd heard from users, which was overwritten work, not lack of live cursors. I asked her which user problem mattered more to solve first. **Result**: She chose Option B, we shipped in 9 days, and it fully addressed the support tickets that had prompted the request in the first place. We revisited true real-time editing a quarter later as a follow-up, once we had data showing it was actually needed."

The translation move — turning a technical estimate gap into two concrete, decidable options — is the actual skill being tested.

## Your template

```
Situation: [where engineering reality and a stakeholder's expectation diverged]
Task: [what you were responsible for resolving or explaining]
Action: [how you translated the trade-off into decidable terms for them]
Result: [outcome] + [evidence the working relationship held up]
```

## Do / Don't

| Do | Don't |
|---|---|
| Show you translated jargon into a decision they could make | Recount a technical explanation they clearly didn't need |
| Give them real options, not just "no" | Present the constraint as immovable with no alternative |
| Credit their input in the final plan | Make it a story about educating them |

## Today's checklist
- [ ] Write STAR story about working with cross-functional team
- [ ] Include: PM, designer, or other stakeholder interaction
- [ ] Practice: "Tell me about working with non-engineers"

**Revision tasks:**
- [ ] Review graph traversal patterns
- [ ] Review REST API design principles
