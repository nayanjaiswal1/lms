---
kind: lesson
id_key: interview-prep-45/backend-django-debugging-labs
course: interview-prep-45
section: backend-django
section_title: "Django"
section_position: 7
section_group: "Backend"
title: "Django in Production: Debugging Labs"
position: 6
estimated_minutes: 15
source:
    - docs/debug-labs.md
---

Backend interviews increasingly include a debugging round: you are handed a slow endpoint, a wrong number or a flaky test in an unfamiliar codebase and asked to find out why, out loud. The questions in this section so far test what you know about Django. This lesson points you at the place where you practice what you do when something is broken.

## What a debugging round actually scores

Interviewers rarely care whether you find the bug in the first minute. They watch the process: do you reproduce the problem before touching the code, do you form a hypothesis and test it with a measurement, do you fix the cause instead of the symptom, and can you explain what you changed and how you know it works. A candidate who says "the query count grows with the number of rows, so I will look at where the page evaluates related objects" is already ahead of one who starts adding caches.

```knowledge-check
{ "questions": [
    { "id": "backend-django-debugging-labs-process-q1", "type": "mcq",
      "prompt": "In a debugging interview you are told a page is slow for some users. What do interviewers most want to see first?",
      "options": [
        {"id":"a","text":"An immediate fix, whatever it is"},
        {"id":"b","text":"You reproduce it with realistic data and measure it (for example count the queries) before changing code"},
        {"id":"c","text":"You rewrite the page from scratch"},
        {"id":"d","text":"You blame the database"}
      ],
      "correct": "b",
      "explanation": "The process is what is scored: reproduce, measure, form a hypothesis, fix the cause, verify. Jumping to a fix is the classic red flag." }
] }
```

## Practice on realistic, broken systems

The **Production Debugging** course gives you exactly that practice. Every lab is a small e-commerce Django app in a browser IDE with a real git history, a database, logs and a ticket written the way support or an on-call engineer would write it. A hidden test suite and behavioral checks grade your fix, and you finish with a short incident write-up. Start with these three, chosen to match what Django interviews probe most:

- **The order list page is slow for repeat customers** (easy): an N+1 query pattern. Practice counting queries and using `select_related` and `prefetch_related`.
- **Evening orders land on tomorrow's report** (medium): time zones and where the conversion from UTC happens.
- **The last unit is sold twice** (hard): a lost update under concurrent checkouts, fixed atomically in the database.

Browse them in the [debug lab catalog](/labs/catalog?kind=debug&stack=django), or open the Production Debugging course from the course list.

```knowledge-check
{ "questions": [
    { "id": "backend-django-debugging-labs-practice-q1", "type": "mcq",
      "prompt": "Which lab skill maps to the interview question \"why does this page get slower as the customer has more orders?\"",
      "options": [
        {"id":"a","text":"Counting queries and finding the N+1 pattern in the queryset"},
        {"id":"b","text":"Changing the server timezone"},
        {"id":"c","text":"Adding a lock around the view"},
        {"id":"d","text":"Rewriting the template engine"}
      ],
      "correct": "a",
      "explanation": "Cost that grows with the number of rows is the signature of per-row work, most often an N+1 query pattern that select_related and prefetch_related remove."
    }
] }
```

## How to use the labs for interview prep

Do each lab twice. The first time, solve it. The second time, narrate: say what you are measuring and why, as if an interviewer were watching, and write the `INCIDENT.md` in five sentences you could say out loud. The write-up (symptom, how you reproduced it, root cause, fix, prevention) is exactly the structure of a strong debugging answer.

```knowledge-check
{ "questions": [
    { "id": "backend-django-debugging-labs-narrate-q1", "type": "mcq",
      "prompt": "What should a good incident write-up or spoken debugging answer contain?",
      "options": [
        {"id":"a","text":"Only the final diff"},
        {"id":"b","text":"Symptom, how you reproduced it, the root cause and mechanism, the fix, and how to prevent it coming back"},
        {"id":"c","text":"A list of every command you ran"},
        {"id":"d","text":"An apology"}
      ],
      "correct": "b",
      "explanation": "The structure shows you understand the mechanism and the prevention, not just the patch."
    }
] }
```
