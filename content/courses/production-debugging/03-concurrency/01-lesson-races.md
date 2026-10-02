---
kind: lesson
id_key: production-debugging/lesson-concurrency-races
course: production-debugging
section: django-concurrency
section_title: "Concurrency"
section_position: 3
section_group: "Django"
title: "Debugging races: make the bug happen on purpose"
position: 1
estimated_minutes: 25
source:
    - docs/debug-labs.md
---

Race conditions are bugs that depend on timing, so they vanish when you look at them. Clicking through the site never shows them; a busy Tuesday does. The skill this section trains is refusing to reason about a race in your head and instead building a small experiment that makes it happen every time.

## Reproduce with load, not with clicks

A race needs two things to overlap. Send many identical requests at once (a thread pool and a short script is enough) against a state where only one of them should win: a product with 5 units in stock, an email address that may be registered once. Then assert an invariant about the data afterwards: stock never negative, sold units equal to stock removed, exactly one account per email. If the invariant breaks, you have a reproduction. If it never breaks, make the window bigger (more requests, a slower step in the middle) rather than concluding it is fine.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-conc-repro-q1", "type": "mcq",
      "prompt": "You suspect two requests can oversell the last unit. What is the most useful reproduction?",
      "options": [
        {"id":"a","text":"Click the buy button twice quickly in the browser"},
        {"id":"b","text":"Fire many concurrent purchase requests at a product with a small stock and check the stock and the number of successful orders afterwards"},
        {"id":"c","text":"Read the code very carefully and decide it is fine"},
        {"id":"d","text":"Restart the server and try again"}
      ],
      "correct": "b",
      "explanation": "A race needs overlapping requests. Concurrent requests against a tiny stock, followed by an invariant check on the data, turns a rare timing problem into a repeatable failure." }
] }
```

## Read-modify-write is the classic shape

Most races in web apps have the same shape: read a value, decide in Python, write a value back. Between the read and the write, someone else's request does the same thing, and one of the writes silently wins (a lost update). The same shape appears as check-then-insert: "does this email exist? no, so insert it", where two requests both see "no".

The cure is to make the check and the change one step the database guarantees. A conditional `UPDATE ... WHERE stock >= n` with an `F()` expression is atomic; `select_for_update()` inside a transaction locks the row while you work; a unique constraint is the only reliable arbiter of "at most one".

```knowledge-check
{ "questions": [
    { "id": "production-debugging-conc-shape-q1", "type": "mcq",
      "prompt": "Which change removes the lost update in a stock reservation?",
      "options": [
        {"id":"a","text":"Reading the row, checking on_hand in Python, and saving on_hand - 1"},
        {"id":"b","text":"One UPDATE statement that decrements on_hand only where on_hand is at least the quantity, checking how many rows it changed"},
        {"id":"c","text":"Adding a time.sleep before saving"},
        {"id":"d","text":"Wrapping the read-modify-write in try/except"}
      ],
      "correct": "b",
      "explanation": "A single conditional UPDATE makes the check and the decrement atomic in the database. Zero updated rows means the stock was not enough. Python-side checks, sleeps and exception handling do not close the window between read and write." }
] }
```

## Let the constraint decide, and handle its answer

When the rule is "at most one", enforce it with a unique constraint and make the code expect the failure: insert inside an atomic block, catch the integrity error, and turn it into the normal answer (409, "already registered"). A pre-check is still fine as a friendly fast path, but it can never be the guard. And be suspicious of in-process fixes: a Python lock only serialises threads of one process, and production runs several workers on several machines.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-conc-constraint-q1", "type": "mcq",
      "prompt": "Why is a module-level threading.Lock around check-then-insert not a real fix for a signup race?",
      "options": [
        {"id":"a","text":"Locks are too slow in Python"},
        {"id":"b","text":"It only serialises threads inside one process; other workers and hosts still race, and the database constraint is what actually guarantees uniqueness"},
        {"id":"c","text":"Django does not allow locks"},
        {"id":"d","text":"It fixes the race completely in every deployment"}
      ],
      "correct": "b",
      "explanation": "Production runs multiple processes and machines. Only the database can arbitrate between them, so the fix is the constraint plus handling its error." }
] }
```

In both labs the graders run the same experiment you should: many concurrent requests plus an invariant check, and a deterministic test that forces the interleaving.
