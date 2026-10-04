---
kind: lesson
id_key: interview-prep-45/company-research
course: interview-prep-45
section: behavioral
section_title: "Behavioral & Interview Day"
section_position: 13
title: "Company Research"
position: 10
estimated_minutes: 25
source:
    - final-prep/40-lesson.md
---

## Why research beats winging it

Two candidates can give the exact same technical answer, and one of them still loses the "why do you want to work here" question. The difference is never talent, it's homework. Research your actual target companies, the ones you have real interviews with, not aspirational ones you're dreaming about. Give each one about 30 minutes, structured, not a random scroll through their website the night before.

## A 30-minute research plan

| Minutes | What to look up | Why it matters |
|---|---|---|
| 0-8 | Engineering blog, last 6-12 months of posts | Reveals real architecture decisions, current problems, and the vocabulary the interviewer uses daily |
| 8-14 | Tech stack, from job postings and blog mentions | Lets you tailor system design answers to tools they'd actually reach for |
| 14-20 | Recent news: funding, launches, incidents, leadership changes | Turns "do you have questions for us" from generic into specific |
| 20-26 | The product itself: use it if consumer-facing, or read the docs if it's a developer tool | You should be able to name one thing you'd improve, and why |
| 26-30 | Interview reports for this specific role, read with a skeptical eye for patterns | Calibrates the format and difficulty to expect |

> **Remember:** 30 minutes, structured, beats an hour of unfocused browsing. Each block has a specific output you'll use in the interview.

```knowledge-check
{ "questions": [
    { "id": "ip45-beh-10-plan-q1", "type": "mcq",
      "prompt": "Why does reading a company's recent engineering blog posts matter more than reading their homepage?",
      "options": [
        {"id":"a","text":"It doesn't; the homepage covers the same information"},
        {"id":"b","text":"It reveals the real architecture decisions, current problems, and the specific vocabulary the interviewer actually uses"},
        {"id":"c","text":"Engineering blogs are required reading before any technical round"},
        {"id":"d","text":"It's the fastest way to learn the company's stock price"}
      ],
      "correct": "b",
      "explanation": "A homepage is marketing copy. An engineering blog shows what the team is actually building and struggling with right now, which is exactly what a good interview answer should connect to." }
] }
```

## Turning research into interview material

Research is only useful once it becomes something you'll actually say out loud. For each target company, prepare three concrete things:

1. **One system design tailored to their domain.** Fintech points toward consistency and idempotency, ad tech toward high-throughput event pipelines, a developer tool toward API design and multi-tenancy.
2. **Two questions to ask the interviewer that could only apply to this company.** Not "what's the culture like," but something like "your engineering blog mentioned moving from a monolith to services around [event]. What's the current pain point in that architecture?"
3. **One honest answer to "why us"** that references something specific from your research, not the company's own marketing copy read back to them.

## Preparing a company-specific behavioral answer

Confirm you have a tailored answer ready for each target company covering "why this company," "why this role," and one story pre-mapped to a value or principle they publicly emphasize. Check their careers page or engineering blog for what they signal; Amazon's published Leadership Principles are the most explicit version of this, but most companies signal something, even if it's less formal.

Finalize your list of questions to ask: two that are company-specific, plus two or three good generic ones, like team structure, what success looks like in six months, or current technical challenges. Have more ready than you'll use; not every interviewer leaves you the same amount of time.

> **Remember:** a question that could only apply to this one company is worth more than three generic ones.

```knowledge-check
{ "questions": [
    { "id": "ip45-beh-10-material-q1", "type": "mcq",
      "prompt": "Which closing question to an interviewer is strongest?",
      "options": [
        {"id":"a","text":"\"What's the culture like here?\""},
        {"id":"b","text":"\"Your engineering blog mentioned moving from a monolith to services last year. What's the current pain point in that architecture?\""},
        {"id":"c","text":"\"Do you offer good benefits?\""},
        {"id":"d","text":"\"How many people work at this company?\""}
      ],
      "correct": "b",
      "explanation": "A question built from real research could only be asked by someone who actually did the homework, which is exactly the signal a generic question fails to send." }
] }
```

## Common mistakes

- Researching aspirational companies you don't have interviews with instead of your actual pipeline.
- Reciting the company's own marketing language back to them as your "why us" answer.
- Showing up with only generic questions to ask, none specific to that company.
- Treating research done weeks ago as still current, without a quick check for anything new.

> **Remember:** company research isn't trivia. It only counts once it turns into a specific design, a specific question, or a specific story.
