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
## Bearer token vs token authentication vs RBAC: three different layers

These three get conflated because they all show up in the same `Authorization` header, but each one answers a different question.

**Bearer token** is a *transport scheme*, not a credential type. It means "whoever holds this token is authorized," sent as `Authorization: Bearer <token>`. It says nothing about what the token contains or how it was issued. A JWT, an opaque session ID, and a raw API key can all be sent as bearer tokens; "bearer" only describes how the value travels in the header, not what's inside it.

**Token authentication** is the *authentication* mechanism: proving who you are. Django REST Framework's `TokenAuthentication` is one concrete implementation of this. It stores an opaque token server-side per user and looks it up on each request, so the token itself carries no information, unlike a JWT, which is self-contained.

**RBAC (Role-Based Access Control)** is the *authorization* model: once the system knows who you are, what are you allowed to do. Permissions attach to roles, users are assigned one or more roles, and endpoints check role membership rather than checking individual users one by one.

The interview framing that ties these together: authentication answers "who is this," authorization answers "what can they do." A request can be perfectly authenticated (a valid bearer token naming a known user) and still get rejected by RBAC, because that user's role doesn't permit the action being requested. Don't let "bearer token" stand in for the whole auth story. It's just the envelope the credential travels in, not the credential itself and not the permission check that happens after.

## BullMQ

BullMQ is a Redis-backed job queue for Node.js, the JS-ecosystem equivalent of Celery. The core idea is the same either way: offload work out of the request/response cycle onto workers that pull from a shared queue, so a slow operation (sending an email, generating a report) doesn't make the HTTP client wait for it.

```js
import { Queue, Worker } from 'bullmq';

const connection = { host: 'localhost', port: 6379 };
const emailQueue = new Queue('emails', { connection });

// producer: enqueue instead of blocking the request
await emailQueue.add('welcome-email', { userId: 42 }, {
  attempts: 3,
  backoff: { type: 'exponential', delay: 1000 },
});

// consumer: separate process
new Worker('emails', async (job) => {
  await sendWelcomeEmail(job.data.userId);
}, { connection });
```

Walking through what happens when this runs: the producer process calls `emailQueue.add`, which pushes a job (the string name `'welcome-email'` plus the `{ userId: 42 }` payload) onto a Redis-backed list/stream structure and returns immediately, without waiting for the email to actually send. Somewhere else, possibly on a different machine, a `Worker` process is polling that same queue. It picks up the job, runs the async callback with `job.data`, and if `sendWelcomeEmail` throws, BullMQ automatically retries using the exponential backoff schedule configured on `attempts`/`backoff`, up to 3 total attempts before giving up.

What BullMQ adds over a plain Redis list: delayed jobs (run at a future timestamp), automatic retries with backoff (as configured above), priority queues, and rate limiting per queue. That's the same category of features Celery gives you, just fitting into a Node stack instead of a Python one, so a candidate coming from a Python background can map BullMQ concepts onto Celery concepts one-to-one.
