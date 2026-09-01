---
kind: lesson
id_key: interview-prep-45/day-12-behavioral
course: interview-prep-45
section: behavioral
section_title: "Behavioral"
section_position: 5
title: "Handling Ambiguity Story"
position: 12
estimated_minutes: 15
source:
    - 45-day-interview-roadmap.md
---
## Why interviewers ask this

Specs are never complete. "Tell me about a time requirements were unclear" checks whether you freeze, guess silently and build the wrong thing, or actively work to reduce the ambiguity before committing engineering time. This is one of the clearest senior-vs-junior signals in the entire interview: junior engineers wait to be told exactly what to build, senior engineers know how to get clarity themselves.

## The framework: STAR, plus a clarifying-questions technique

Same STAR shape as prior days. The Action section needs to show a specific technique for surfacing what was actually unclear, beyond just "I asked some questions."

A reliable technique: **state your assumption out loud before building.** Instead of asking an open-ended "what do you want here?", propose a specific interpretation, something like "I'm going to assume X, and build accordingly unless you tell me otherwise by end of day." That forces a fast yes/no rather than an open-ended discussion, and gives the other person something concrete to react to instead of a blank page.

## Worked example

> **Situation**: "I was asked to 'add export functionality' to a reporting dashboard, with no spec on format, scope, or who'd use it. The PM who requested it was out for two days. **Task**: I needed to start building something useful without burning those two days waiting, and without guessing wrong and rebuilding later. **Action**: I looked at who used the dashboard today, mostly finance and ops, and made a specific assumption: CSV export of the currently filtered view, since that's the most common pattern for that kind of report and the lowest-effort correct guess. I wrote a one-paragraph doc stating that assumption and posted it in the team channel, flagging that I'd start on it and could adjust before it shipped if the assumption was wrong. I also built the export logic behind a small interface so swapping CSV for, say, PDF later wouldn't mean a rewrite. **Result**: The PM came back, confirmed CSV was exactly right, and added one detail I hadn't guessed: it needed to preserve applied filters in the filename for finance's audit trail, which was a 20-minute addition, not a rebuild. Stating the assumption up front meant I didn't lose two days, and the interface choice meant the one thing I did guess wrong on was cheap to fix."

The pattern: assume specifically, state it publicly, build so the guess is cheap to reverse.

## Your template

```
Situation: [what was unclear, and why waiting for full clarity wasn't an option]
Task: [what you needed to deliver despite the gap]
Action: [the specific assumption you made] + [how you surfaced it] + [how you kept the guess cheap to reverse]
Result: [outcome] + [what you'd have gotten wrong without the technique]
```

## Do / Don't

| Do | Don't |
|---|---|
| State a specific assumption, not an open question | Ask "what do you want?" and wait passively |
| Build so a wrong guess is cheap to fix | Fully commit to one interpretation with no flexibility |
| Communicate the assumption before shipping | Silently guess and reveal the guess only at review |
