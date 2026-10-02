---
kind: lesson
id_key: production-debugging/lesson-service-calls-failure-modes
course: production-debugging
section: django-service-calls
section_title: "Calls to other services"
section_position: 6
section_group: "Django"
title: "Debugging calls to other services: design for the failure"
position: 1
estimated_minutes: 20
source:
    - docs/debug-labs.md
---

Every outbound call is a promise about a machine you do not control. Bugs in this area rarely appear when the other service is healthy, so the skill this section trains is making the other side misbehave on purpose and watching what your code does.

## Reproduce by making the dependency slow, flaky or different

The lab environment ships a stand-in for the payments provider that you can make slow, make fail after it has done the work, or make answer in a new format. Use that: put the dependency into the bad state, run the operation, and watch three things. How long does the request wait? What state does your database end up in? What does the customer see? A ticket that says "checkout hangs" is answered by the first; "customers were charged twice" by the second.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-svc-repro-q1", "type": "mcq",
      "prompt": "Checkout hangs only when the payments provider is having a bad day. How do you reproduce it?",
      "options": [
        {"id":"a","text":"Wait for the provider to have another bad day"},
        {"id":"b","text":"Make the provider stand-in slow on purpose and time the request"},
        {"id":"c","text":"Increase the number of web workers"},
        {"id":"d","text":"Read the provider's documentation"}
      ],
      "correct": "b",
      "explanation": "Dependency faults must be injected deliberately: slow it, fail it, change its answer. Then the behavior of your code is observable and repeatable." }
] }
```

## Every call needs a timeout and a failure mode

The `requests` library waits forever unless you give it a timeout. While a call waits, a worker thread and usually a database transaction are held, so one slow dependency can starve unrelated pages. Decide, for each outbound call, the longest you are willing to wait (separate connect and read limits), what happens when that expires (retry? which error to the user?), and whether retrying is safe. Retrying a charge is only safe if the provider can recognise it as the same request, which is what an idempotency key is for.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-svc-timeout-q1", "type": "mcq",
      "prompt": "A request to the payments provider has no timeout and the provider stops answering. What happens?",
      "options": [
        {"id":"a","text":"The requests library gives up after 30 seconds by default"},
        {"id":"b","text":"The call can wait indefinitely, holding a worker and its open transaction, and requests pile up behind it"},
        {"id":"c","text":"Django raises an exception after 5 seconds"},
        {"id":"d","text":"The database aborts the request"}
      ],
      "correct": "b",
      "explanation": "requests has no default timeout. The waiting request keeps its worker thread and transaction, so unrelated requests queue behind it." }
] }
```

## Fail loudly and locally

When a dependency changes or breaks, the worst outcome is a silent default: a missing field treated as zero, an unexpected status treated as declined. Prefer strict parsing that raises a clear error at the boundary, and translate provider failures into your own explicit error types and HTTP answers (service unavailable, bad gateway). Then test the boundary: a fake client that times out, fails, or answers in the wrong shape.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-svc-loud-q1", "type": "mcq",
      "prompt": "The provider renames a response field and your code does data.get('status', 'declined'). What is the risk?",
      "options": [
        {"id":"a","text":"None, defaults make code robust"},
        {"id":"b","text":"Every charge silently looks declined; a strict parse that raises a clear contract error would surface the change immediately"},
        {"id":"c","text":"The provider will reject the request"},
        {"id":"d","text":"Django will fail to start"}
      ],
      "correct": "b",
      "explanation": "A silent default hides a contract change behind wrong business behavior. Failing loudly at the boundary turns it into an alert instead of lost sales."
    }
] }
```
