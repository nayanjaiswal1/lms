---
kind: lesson
id_key: interview-prep-45/day-22-behavioral
course: interview-prep-45
section: behavioral
section_title: "Behavioral"
section_position: 5
title: "Communication Story"
position: 22
estimated_minutes: 15
source:
    - 45-day-interview-roadmap.md
---
## Why interviewers ask this

"Explain X to a 5-year-old," or "tell me about explaining something technical to a non-technical person," tests a skill most engineers underrate: can you translate technical reality for a PM, a support rep, or an executive who needs to make a decision without understanding the implementation. Teams stall when engineers can only communicate in their own vocabulary.

## The framework: STAR, weighted on the translation technique

- **Situation**: who you needed to explain something to, and what decision or understanding depended on it.
- **Task**: the technical concept itself, and why a technical explanation wouldn't have worked for this audience.
- **Action**: the specific technique you used to translate it: an analogy, a visual, breaking it into a decision they actually needed to make rather than how the system works internally.
- **Result**: the decision they made or the outcome, proving the translation worked, not just that you talked at them.

## Worked example

> **Situation**: "Our support team kept escalating a bug report as 'the app is randomly slow' with no pattern, and I needed our head of support, who has no engineering background, to understand it was a database indexing issue so she could set the right customer expectations. **Task**: I needed her to understand enough to communicate an accurate timeline to customers, not to understand query planning. **Action**: Instead of explaining B-tree indexes, I used an analogy: right now, finding one customer's order is like flipping through every page of a phone book instead of jumping straight to the right letter. It works, it's just slow, and it gets slower as the phone book grows. I told her the fix was 'building an index card system for the phone book' and that it would take about a week, with the app getting progressively less slow as we added it to different tables, not fixed all at once. **Result**: She was able to tell customers 'we've found the cause and it'll be progressively resolved over the next week' instead of 'we're looking into it,' which cut escalation volume immediately. She also started using the phone-book analogy herself when explaining performance issues to customers afterward, which told me it had actually landed."

The analogy being reused by someone else afterward is the proof the translation worked.

## Your template

```
Situation: [who needed to understand, and what decision depended on it]
Task: [the technical concept] + [why a technical explanation wouldn't have worked]
Action: [the specific analogy or technique you used to translate it]
Result: [the decision/outcome that followed] + [evidence the explanation actually landed]
```

## Do / Don't

| Do | Don't |
|---|---|
| Use a concrete analogy tied to something familiar | Simplify by leaving out the point entirely |
| Tie the explanation to a decision they needed to make | Explain for the sake of explaining |
| Show evidence they understood, not just that you talked | Assume nodding along means comprehension |
