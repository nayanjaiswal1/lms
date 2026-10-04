---
kind: lesson
id_key: interview-prep-45/day-01-behavioral
course: interview-prep-45
section: behavioral
section_title: "Behavioral & Interview Day"
section_position: 13
title: "Resume and Project Walkthroughs"
position: 1
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---

## What the interviewer is really checking

"Walk me through your resume" is usually the very first question in the room. Nobody actually wants your life story: they want proof that you can explain your own work clearly, pick out what matters, and connect your background to the job you're sitting in front of them for. This happens before a single technical question, so it sets the tone for everything after it.

A little later, "tell me about a project you're proud of" checks something different: whether your resume bullets are real. Interviewers want to watch you reason about trade-offs and own outcomes, not recite what the code did line by line.

## The shape of a resume walkthrough: Present, Past, Future

A strong walkthrough is three short paragraphs, always in the same order:

1. **Present**: who you are right now. Your current role, your company (one line of context if it's not a household name), and the stack or domain you work in.
2. **Past**: the one or two achievements that best set up the rest of the interview. Lead with what changed because of your work, not a list of tasks, and attach a number wherever you can.
3. **Future**: why you're looking to move, and what you want next. Point this straight at the role you're interviewing for, not a generic line about "growth."

Say the whole thing out loud in 90 to 120 seconds. If you're still talking at three minutes, you've packed in too much, and the interviewer will pull the thread on whatever they find most interesting anyway, so you don't need to cover everything yourself.

A weak walkthrough lists every job since college in order, with no throughline connecting them. A strong one picks the 20% of your history that matters for this interview and compresses the rest into a half-sentence.

> **Remember:** present, past, future, in that order, under two minutes. Pick the 20% of your history that matters here.

```knowledge-check
{ "questions": [
    { "id": "ip45-beh-01-ppf-q1", "type": "mcq",
      "prompt": "A candidate spends 3 minutes listing every job since college with no clear throughline. What is the biggest problem with this walkthrough?",
      "options": [
        {"id":"a","text":"It's too short to be useful"},
        {"id":"b","text":"It has no throughline connecting the jobs to the role at hand, and it runs long enough that the interviewer never gets to ask a follow-up"},
        {"id":"c","text":"It should include every project in full technical detail"},
        {"id":"d","text":"Interviewers prefer walkthroughs that start with the earliest job first"}
      ],
      "correct": "b",
      "explanation": "A resume walkthrough is a pitch, not a transcript. Present, Past, Future in under two minutes leaves room for the interviewer to dig into whatever they actually care about." }
] }
```

## Worked example

> "I'm currently a backend engineer at a logistics startup, working mostly in Go and Postgres building the systems that route delivery orders to drivers. Before that, I spent three years at a mid-size fintech company, where I led the rebuild of our payments reconciliation pipeline. It cut manual reconciliation time from two days a month to under an hour, and it's still the system of record there now. I'm looking to move now because I've hit the ceiling of what a 15-person engineering team can throw at me. I want to work on problems at higher scale, with more experienced engineers around me, which is what drew me to this role."

One number, one system named, one honest reason for moving. That's the whole recipe. Write your own version with this template:

```
Present: I'm currently a [role] at [company], where I [what you do day to day, name the stack or domain].
Past: Before that / also at [company], I [project or achievement], which [what changed, with a number].
Future: I'm looking to move now because [specific, honest reason], and I'm drawn to [this role] because [specific connection].
```

## Picking two projects that show range, not repetition

A single project deep dive proves you can build something. A second one, chosen well, proves you're not a one-trick pony. Pick your second project deliberately to cover a gap your first one doesn't:

- If project one showed deep technical execution, pick a project two that shows handling ambiguity or working across teams.
- If project one was a solo build, pick a project two that was a team effort, one where your own contribution is easy to separate out.
- If project one is recent, a project two from a couple of years back shows growth over time.

If both stories prove "I can write good backend code" and nothing else, you've spent two of your slots on one message.

For each project, use the same five-part shape, called **PSICD**:

- **Problem**: what was broken or missing, in user or business terms first, technical terms second.
- **Solution**: the system you actually built, at a level of detail another engineer outside your team could follow.
- **Impact**: what changed, with a number. Latency, cost, error rate, adoption: whatever's real.
- **Challenges**: the hardest part, and specifically why it was hard. "There was a lot to do" isn't a challenge.
- **Decisions**: one real trade-off you made, the alternative you turned down, and why.

Interviewers dig into whichever part sounds thinnest, so don't pad the pieces you can't defend under a follow-up question.

> **Remember:** two deep dives, chosen for contrast, both told as Problem, Solution, Impact, Challenges, Decisions.

```knowledge-check
{ "questions": [
    { "id": "ip45-beh-01-psicd-q1", "type": "mcq",
      "prompt": "Why should your second project deep dive be chosen for contrast with the first one, rather than for how comfortable you are telling it?",
      "options": [
        {"id":"a","text":"Because interviewers always ask for the harder story second"},
        {"id":"b","text":"Because two stories that both prove the same single skill waste one of your two chances to show range"},
        {"id":"c","text":"Because the second story should always be more recent"},
        {"id":"d","text":"Because contrast makes the story easier to memorize"}
      ],
      "correct": "b",
      "explanation": "You only get a couple of deep dives in most interviews. If both showcase the same skill, an interviewer learns less about you than if the two together cover, say, technical depth and cross-team coordination." }
] }
```

## Worked example: two deep dives back to back

> **Project one (technical depth).** "Problem: our checkout flow was losing about 8% of orders to timeout errors during peak traffic, because the inventory service made a synchronous call to three downstream systems per item. Solution: I redesigned it around an async reservation queue. Checkout would grab a soft hold on inventory right away and confirm it in the background, with a 2-second SLA before falling back to the old synchronous path. Impact: timeout-related checkout failures dropped from 8% to under 0.5%, and P99 checkout latency went from 4.2 seconds to 600 milliseconds. Challenges: the hardest part was the fallback path. If the async confirmation failed, we had a small window where we could oversell inventory, so I added a reconciliation job that ran every minute to catch and reverse those cases. Decisions: I considered a full event-sourced inventory system instead, which would have solved overselling more elegantly, but it was a six-week rewrite against a one-week patch, and the business needed the fix before the holiday traffic spike."

> **Project two (cross-team coordination).** "This one's a good contrast, because it was less about technical difficulty and more about getting three teams to agree on ownership. Problem: we had 40-plus alert rules with no clear owner, so pages went to whoever was on call, and time to acknowledge an alert kept climbing. Solution: I mapped every alert to a specific service owner, built a routing layer on top of our existing paging tool, and ran a two-week trial with the two loudest teams before rolling it out everywhere. Impact: time to acknowledge dropped from 14 minutes to under 3, and on-call complaints in our engineering survey dropped noticeably the next quarter. Challenges: the hardest part wasn't the code, it was getting a team that didn't want to own a noisy alert to actually take it, which took a few one-on-one conversations. Decisions: I built the routing layer on our existing tool instead of migrating to a new alerting platform, because that migration would have needed months of buy-in I didn't have time for."

## Common mistakes

- Narrating your entire career history instead of the 20% that matters for this role.
- Saying "it made things a lot faster" instead of a number, even a rough one.
- Picking two projects that prove the exact same skill.
- Only ever saying these stories in your head. Say them out loud, timed, before the interview.

> **Remember:** if you haven't said a story out loud with a timer running, it isn't ready yet.
