---
kind: lesson
type: system_design
id_key: interview-prep-45/day-25-system-design
course: interview-prep-45
section: system-design
section_title: "Case Studies"
section_position: 4
section_group: "System Design"
title: "Design a Payment System"
position: 20
estimated_minutes: 70
source:
    - 45-day-interview-roadmap.md
---

A payment system is what the checkout flow treats as an external black box: the thing that actually moves money. This is the strictest-consistency design in the whole course, because the domain has zero tolerance for the sloppy trade-offs that are fine elsewhere. No double charges, no lost money, full auditability, and regulatory rules (PCI compliance) that shape the architecture directly instead of being an afterthought.

## Requirements

**Functional requirements**
- Process a payment (charge a card or other method) for an order.
- Support full and partial refunds.
- Support disputes and chargebacks initiated by the payment network or the cardholder.
- Provide an auditable transaction history.

**Non-functional requirements**
- Idempotency is non-negotiable. The same charge request, retried, must never result in two charges.
- Strong consistency on money movement: a payment's state must be unambiguous at all times, never silently lost.
- Security: PCI-DSS compliance constrains where raw card data is even allowed to live.
- Auditability: every state transition is logged, immutable, and traceable, required for debugging and for regulatory and dispute purposes.
- Reliability over raw throughput. This system would rather be slow and correct than fast and wrong.

> **Remember:** every other system in this course has picked availability or speed over consistency somewhere. This one doesn't. If an interviewer asks you to trade correctness for speed here, the right answer is to push back.

```knowledge-check
{ "questions": [
    { "id": "system-design-payments-requirements-q1", "type": "mcq", "prompt": "Why does a payment system prioritize correctness and reliability over raw throughput, unlike most other systems in this course?", "options": [
        {"id": "a", "text": "Payment systems never actually need to scale"},
        {"id": "b", "text": "The cost of getting it wrong is a real, unrecoverable loss of money or a double charge, which is categorically worse than the cost of being briefly slow"},
        {"id": "c", "text": "Throughput and correctness are the same thing"},
        {"id": "d", "text": "Payment providers handle all correctness concerns automatically"}
    ], "correct": "b", "explanation": "Unlike a stale like count or a slightly delayed feed, a payment error has a real financial consequence with no acceptable margin, which is exactly why this system leans so heavily toward correctness." }
] }
```

## Estimates

Reuse the checkout volume from the e-commerce design: roughly 10 million successful payments a day, 33 million payment attempts a day including failures and abandonment.

- **Peak rate:** 33,000,000 / 86,400 ≈ 380/sec average, several times higher during a flash sale, modest compared to the read-heavy systems earlier in this course. That's the point: this system's hard problem is correctness, not throughput.
- **Refunds:** assuming roughly 5% of orders are refunded, that's 500,000 refund operations a day, a much lower-volume, non-latency-critical path.
- **Audit retention:** financial and regulatory requirements typically mandate multi-year retention, often 7 years, a very different storage lifecycle than something like raw analytics events, which can be pruned aggressively.
- **Disputes:** a small fraction of transactions, typically well under 1%, but each one needs a fully reconstructable history. This is a low-volume, high-stakes-per-record workload, the opposite shape from most systems in this course.

## API

```
POST /payments/charge      { order_id, amount, payment_method_token, idempotency_key }
  -> { payment_id, status: "pending"|"succeeded"|"failed" }

GET  /payments/{id}                          -> { status, amount, order_id, history[] }
POST /payments/{id}/refund { amount?, reason, idempotency_key }
  -> { refund_id, status }

POST /webhooks/payment-provider               -- inbound async status updates from the provider
GET  /payments/{id}/audit-log                 -> { events[] }   -- immutable event history
```

Notice `payment_method_token`, not a raw card number. The API never accepts a raw card number from your own backend at all; tokenization happens client-side directly against the payment provider, covered in the PCI deep dive below.

## Data model

```
payments           id, order_id, amount, currency, status (pending|succeeded|failed|refunded|
                    partially_refunded), provider_ref, idempotency_key, created_at, updated_at
payment_events      id, payment_id, event_type (charge_attempted|charge_succeeded|charge_failed|
                    refund_issued|dispute_opened), payload, created_at   -- append-only, immutable
refunds             id, payment_id, amount, status, provider_ref, created_at
disputes            id, payment_id, reason, status, opened_at, resolved_at

UNIQUE constraint on payments.idempotency_key
```

`payment_events` is deliberately append-only and immutable: never update a row, only insert. This is the audit trail, and it's what makes disputes and debugging possible. The `payments.status` column is a derived, cached summary; `payment_events` is the actual source of truth for what happened, and in what order.

```knowledge-check
{ "questions": [
    { "id": "system-design-payments-datamodel-q1", "type": "mcq", "prompt": "Why is payment_events an append-only log instead of just updating payments.status directly as things change?", "options": [
        {"id": "a", "text": "It's redundant and adds no real value"},
        {"id": "b", "text": "A single mutable status field destroys history, while an append-only log preserves the full sequence of what happened, required for disputes and audits"},
        {"id": "c", "text": "Append-only tables are always faster to query"},
        {"id": "d", "text": "It's only needed for regulatory reasons in certain countries"}
    ], "correct": "b", "explanation": "Once a status field is overwritten multiple times, you can no longer reconstruct the full timeline of a transaction. The append-only log is what lets you answer 'what happened, when' for a dispute or an audit." }
] }
```

## High-level design

```
Checkout service --> POST /payments/charge (idempotency_key from the checkout flow)
                            |
                  Payment service: check idempotency_key first (short-circuit duplicates)
                            |
                  write payment_events "charge_attempted" --> call external payment
                  provider (Stripe/Adyen/etc.) with the SAME idempotency key passed through
                            |
                  +---------+----------+
                  |                    |
          synchronous response   async webhook callback
          (immediate accept/     (final settlement status,
           decline for cards)     common for bank transfers,
                  |                3D-Secure follow-up, etc.)
                  |                    |
                  +---------+----------+
                            |
                  write payment_events (succeeded/failed) --> update payments.status
                  --> notify order service (order confirmed / payment failed)
```

## Deep dives

### Why does idempotency have to be enforced at two separate boundaries?

This is the single most important property in the whole system. It has to hold twice: between your checkout client and your payment service, where the idempotency key from checkout is enforced via the unique constraint on `payments.idempotency_key`, so a retried charge call with the same key returns the existing payment record instead of creating a new one, and between your payment service and the external provider, where you pass that same key through to the provider's own API. Stripe, Adyen, and similar providers support this natively, guaranteeing that even if your own service's retry logic double-sends the outbound call, the provider still only charges once.

Two layers, because a failure can happen on either side of that boundary, and each side needs its own protection.

> **Remember:** idempotency at only one layer isn't idempotency. A retry can originate on either side of a network call, so both sides need their own dedup key.

```knowledge-check
{ "questions": [
    { "id": "system-design-payments-idempotency-q1", "type": "mcq", "prompt": "Why isn't a single idempotency key check at the payment service enough to prevent all double charges?", "options": [
        {"id": "a", "text": "It is enough, a second check adds nothing"},
        {"id": "b", "text": "A failure or retry can also happen between the payment service and the external provider, which needs its own idempotency protection independent of the client-facing check"},
        {"id": "c", "text": "Payment providers don't support idempotency keys"},
        {"id": "d", "text": "Idempotency keys expire immediately after use"}
    ], "correct": "b", "explanation": "The client-to-service boundary and the service-to-provider boundary are two separate points where a retry can occur, so each needs its own idempotency guarantee to fully close the double-charge risk." }
] }
```

### Why do webhooks exist instead of just a synchronous response?

Card charges often do resolve synchronously, an approval or decline within the request. But many payment flows are inherently asynchronous: bank transfers settle over days, 3D-Secure authentication needs an out-of-band step from the customer, and disputes are opened by the card network days or weeks later. The system has to treat "final settlement status" as something that can arrive well after the initial request, delivered through a webhook the provider calls back into your system.

Webhook handlers must themselves be idempotent, since providers routinely retry webhook delivery, and must verify the request's authenticity, a signature check against the provider's signing secret, before trusting anything in the payload. An unauthenticated webhook endpoint is a direct path to payment fraud: an attacker could simply POST a fake "payment succeeded" event to mark an order paid without actually paying.

### How does PCI compliance actually shape the architecture?

The single biggest architectural consequence of PCI-DSS: your own backend should ideally never touch a raw card number at all. Card data is tokenized client-side, directly against the payment provider's own SDK or hosted fields. Your frontend collects card details into a component the provider controls, which returns an opaque token, and that token, not the raw number, is what flows through `payment_method_token` in the API above. This dramatically shrinks your PCI compliance scope, since you're handling tokens, not cardholder data, and it's why "just store the card number in our database" is never the right answer in a payments design interview. Say this explicitly; it's a strong signal.

### How do you handle a failed charge, and one where you genuinely don't know the outcome?

A decline, insufficient funds, a fraud flag, an expired card, is a normal expected outcome, not a system failure. Write it to `payment_events`, set the payment's status to failed, and let checkout release its inventory reservation and prompt for a different payment method.

The harder case is an ambiguous failure: the provider call times out, and you genuinely don't know if it succeeded. Never blindly retry a raw charge here, that risks a real double charge. Query the provider's status endpoint using the original idempotency key before deciding whether to retry or treat it as failed, deferring the ambiguity to the one system that actually knows the truth instead of guessing.

### How are refunds and disputes tracked without corrupting the original charge record?

A refund is its own idempotent, auditable operation with its own idempotency key. Never mutate the original payment row's amount; insert a `refunds` row instead, and let the payment's status become `refunded` or `partially_refunded`, preserving the original charge event intact for audit purposes. Disputes are typically initiated by the payment network, not your own API, and arrive as a webhook event, tracked in a `disputes` table through evidence submission and resolution. The append-only `payment_events` log is what lets you reconstruct the full timeline of a disputed transaction on demand, often a contractual or regulatory requirement, not a nice-to-have.

## Trade-offs and follow-up questions

| Decision | Benefit | Cost |
|---|---|---|
| Idempotency keys at two layers (client-to-service, service-to-provider) | Eliminates double-charge risk from a retry at either boundary | Needs careful key scoping and a durable idempotency-key store |
| Append-only payment_events, derived payments.status | Full audit trail, supports dispute reconstruction, never loses history | More storage than mutating one row in place; queries need "latest event" logic |
| Tokenization at the client, never touching raw card numbers server-side | Drastically reduces PCI compliance scope | The frontend must integrate the provider's SDK rather than a plain form |
| Async webhook handling for final settlement status | Correctly models genuinely asynchronous methods (bank transfers, 3DS, disputes) | Webhook handlers must be idempotent and signature-verified, a second ingestion path |

**Q: Your service calls the payment provider's charge API, but the network times out before you get a response. What do you do?**
A: Never blindly retry the raw charge; the original call may have already succeeded on the provider's side. Retry using the same idempotency key, so the provider returns the existing result instead of charging again, or explicitly query the provider's status endpoint for that key before deciding the outcome. Only after confirming genuine non-completion do you mark the payment failed and release the reservation.

**Q: Why not just store payments.status and skip the separate payment_events audit log?**
A: A single mutable status field destroys history. You can no longer answer what happened, in what order, once a row has been overwritten multiple times. Disputes, regulatory audits, and debugging all require the full sequence of events, not just the current state, which is exactly what the append-only log preserves and the status column can't.

**Q: A payment provider sends you a webhook, but you can't tell if it's genuinely from them or spoofed. How do you handle that?**
A: Verify the webhook's cryptographic signature against the provider's published signing secret before processing anything in the payload. Every major provider signs webhook payloads specifically so receivers can authenticate them; skipping this check is a direct fraud vector.

```knowledge-check
{ "questions": [
    { "id": "system-design-payments-tradeoffs-q1", "type": "mcq", "prompt": "Why must a webhook's signature be verified before trusting a 'payment succeeded' event it delivers?", "options": [
        {"id": "a", "text": "Signature verification is optional hardening, not strictly necessary"},
        {"id": "b", "text": "An unverified webhook endpoint could be sent a forged success event by an attacker, marking an order paid without any real payment"},
        {"id": "c", "text": "Webhooks are never actually used for payment status"},
        {"id": "d", "text": "Signatures are only relevant for refunds, not charges"}
    ], "correct": "b", "explanation": "Without signature verification, anyone who discovers the webhook URL could POST a fabricated success event, making signature verification a mandatory first step rather than an optional one." }
] }
```
