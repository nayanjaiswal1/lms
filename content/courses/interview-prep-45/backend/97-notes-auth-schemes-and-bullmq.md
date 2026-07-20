---
kind: lesson
id_key: interview-prep-45/note-auth-schemes-bullmq
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Notes: Bearer/Token Auth vs RBAC, and BullMQ"
position: 97
estimated_minutes: 15
source:
    - interview-prep-notes.md
---
## Bearer token vs Token auth vs RBAC — three different layers

These get conflated because they all show up in the same `Authorization` header, but they answer different questions:

- **Bearer token** — a *transport scheme*: "whoever holds this token is authorized," sent as `Authorization: Bearer <token>`. Says nothing about what the token contains or how it was issued — a JWT, an opaque session ID, and an API key can all be sent as bearer tokens.
- **Token authentication** — the *authentication* mechanism: proving *who you are*. DRF's `TokenAuthentication` is one concrete implementation — an opaque token stored server-side per user, looked up on each request.
- **RBAC (Role-Based Access Control)** — the *authorization* model: once you know who you are, what are you *allowed to do*. Permissions attach to roles, users are assigned roles, and endpoints check role membership rather than checking individual users.

Interview framing: authentication answers "who is this," authorization answers "what can they do" — a request can be perfectly authenticated (valid bearer token, known user) and still be rejected by RBAC (wrong role for this action). Don't let "Bearer token" stand in for the whole auth story — it's just the envelope the credential travels in.

## BullMQ

Redis-backed job queue for Node.js — the JS-ecosystem equivalent of Celery. Same core idea: offload work out of the request/response cycle onto workers that pull from a shared queue.

```js
import { Queue, Worker } from 'bullmq';

const connection = { host: 'localhost', port: 6379 };
const emailQueue = new Queue('emails', { connection });

// producer — enqueue instead of blocking the request
await emailQueue.add('welcome-email', { userId: 42 }, {
  attempts: 3,
  backoff: { type: 'exponential', delay: 1000 },
});

// consumer — separate process
new Worker('emails', async (job) => {
  await sendWelcomeEmail(job.data.userId);
}, { connection });
```

What it adds over a plain Redis list: delayed jobs (run at a future timestamp), automatic retries with backoff (as configured above), priority queues, and rate limiting per queue — the same category of features Celery gives you, just fitting into a Node stack instead of Python's.

## Key takeaways

- Bearer = how the token travels (header scheme). Token auth = *how you prove identity*. RBAC = *what you're allowed to do once identified* — three separate concerns, often confused as one.
- BullMQ is Celery's Node-ecosystem counterpart: Redis-backed, supports retries/backoff, delayed jobs, priorities — same reason you'd reach for either, different runtime.
