---
kind: lesson
id_key: production-debugging/lesson-data-model-data-that-lies
course: production-debugging
section: django-data-model
section_title: "Data model and money"
section_position: 2
section_group: "Django"
title: "Debugging wrong data: trace the value, not the screen"
position: 1
estimated_minutes: 20
source:
    - docs/debug-labs.md
---

Wrong-data bugs are quiet. Nothing crashes: a total is a cent off, a day's revenue lands on the wrong day, a record is simply gone. By the time someone notices, the damage is already stored. The skill here is to stop staring at the screen and follow one wrong value backwards, from where it is displayed to where it was produced.

## Follow one value end to end

Pick one concrete wrong example (order 4812, invoice INV-2025-00031, the 50.00 subtotal) and walk it through the system: what the database holds, what the code reads, what each function returns, what is finally rendered. The first place the value is wrong is where the bug lives, and it is often earlier than you expect. If the stored value is already wrong, the bug is in the write path; if the stored value is right, it is in the read path.

Keep the example small enough to check by hand. A wrong number you can recompute on paper is worth more than a hundred you can only see in aggregate.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-data-trace-q1", "type": "mcq",
      "prompt": "An order total displayed on a page is one cent off. You check the database row and the stored total is already wrong. Where should you look next?",
      "options": [
        {"id":"a","text":"The template that renders the number"},
        {"id":"b","text":"The code path that computed and saved the total"},
        {"id":"c","text":"The browser cache"},
        {"id":"d","text":"The web server configuration"}
      ],
      "correct": "b",
      "explanation": "If the stored value is wrong, the write path produced it; the display code only shows what it was given. Follow the value back to where it was computed." }
] }
```

## Relationships decide what deletion does

Every foreign key answers a question the model author may not have asked: what should happen to me when the row I point at is deleted? `CASCADE` deletes me too, `PROTECT` refuses the deletion, `SET_NULL` keeps me but detaches me. Cascades follow chains: delete a customer and the orders go, and so does everything hanging off the orders. Django even shows you this list on the admin delete confirmation page.

For business records (orders, invoices, payments) the right answer is almost never to lose them. The bug is often a single word in a model, and it can lie dormant for months until someone deletes the wrong row.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-data-ondelete-q1", "type": "mcq",
      "prompt": "Invoice.order is a foreign key with CASCADE, and Order.customer is CASCADE too. What happens when a customer row is deleted?",
      "options": [
        {"id":"a","text":"Only the customer is deleted"},
        {"id":"b","text":"The customer, their orders and those orders' invoices are deleted"},
        {"id":"c","text":"Django refuses because invoices exist"},
        {"id":"d","text":"The orders stay and their customer field becomes empty"}
      ],
      "correct": "b",
      "explanation": "Cascades are transitive: the customer deletion collects the orders, and deleting the orders collects their invoices. PROTECT on the customer relation would refuse the whole operation instead." }
] }
```

## Money is exact and time has a zone

Two families of data bugs come from using the wrong kind of number. Binary floating point cannot represent most decimal fractions exactly, so money computed through floats drifts by a cent in a few percent of cases, and `round()` on a float does not round halves the way accounting expects. Keep money in `Decimal` from input to output and choose the rounding mode on purpose.

Time has the mirror-image problem. Django stores instants in UTC, but a business day (or a report row, or an invoice date) belongs to a time zone, and the offset changes with daylight saving. "Which day was this order placed?" has no answer until you say which zone you mean. Whenever a number sits next to a date, ask what zone the date is in and where the conversion happens.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-data-money-q1", "type": "mcq",
      "prompt": "Why is float(50.00) * float(0.0825) a risky way to compute tax to the cent?",
      "options": [
        {"id":"a","text":"Floats are too slow"},
        {"id":"b","text":"Binary floats cannot represent most decimal fractions exactly, so exact half-cent results can land just below the half and round the wrong way"},
        {"id":"c","text":"Python refuses to multiply floats by floats"},
        {"id":"d","text":"The result is always exactly right"}
      ],
      "correct": "b",
      "explanation": "50.00 at 8.25 percent is exactly 4.125, which must round to 4.13, but the float route can produce a value slightly under 4.125 and round to 4.12. Decimal keeps the arithmetic exact." },
    { "id": "production-debugging-data-money-q2", "type": "mcq",
      "prompt": "An evening order (22:30 in New York) shows up on the next day's revenue row. What is the most likely cause?",
      "options": [
        {"id":"a","text":"The order timestamp was saved incorrectly"},
        {"id":"b","text":"The day was computed in UTC instead of the business time zone"},
        {"id":"c","text":"The revenue query ran too early"},
        {"id":"d","text":"Daylight saving time does not exist in Django"}
      ],
      "correct": "b",
      "explanation": "22:30 in New York is 03:30 UTC the next calendar day. If the report groups by the UTC date, evening orders move to the next row." }
] }
```

Each lab in this section gives you one such lie to run to ground. The fix is only done when a test with a carefully chosen input (the 50.00 subtotal, the order just before midnight, the customer with orders) fails on the old code.
