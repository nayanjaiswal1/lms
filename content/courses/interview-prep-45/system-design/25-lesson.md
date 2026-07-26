---
kind: lesson
type: system_design
id_key: interview-prep-45/day-25-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Design Payment System"
position: 25
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---
Today you design the payment processing system that Day 24's checkout flow treated as an external black box. Payments interviews exist because this domain has zero tolerance for the sloppy trade-offs acceptable elsewhere: no double charges, no lost money, full auditability, and regulatory constraints (PCI compliance) that actively shape the architecture rather than being an afterthought. This is the strictest-consistency system in the whole course.

## Requirements

**Functional**
- Process a payment (charge a card/payment method) for an order.
- Support refunds (full or partial).
- Support disputes/chargebacks initiated by the payment network or cardholder.
- Provide an auditable transaction history.

**Non-functional**
- Idempotency is non-negotiable — the same charge request retried must never result in two charges.
- Strong consistency on money movement: a payment's state must be unambiguous at all times (pending/succeeded/failed), never silently lost.
- Security: PCI-DSS compliance constrains where raw card data can even live.
- Auditability: every state transition must be logged, immutable, and traceable — required for both debugging and regulatory/dispute purposes.
- Reliability over raw throughput — this system would rather be slow and correct than fast and wrong.

## Capacity estimates

Reuse Day 24's checkout volume: ~10M successful payments/day, ~33M payment attempts/day (including failures/abandonment).
- Peak rate: 33M / 86,400 ≈ 380/sec average, several times that during flash sales — modest compared to read-heavy systems earlier in this course, reinforcing that this system's hard problem is correctness, not throughput.
- Refunds: assume 5% of orders refunded (matches Day 23's return rate) → 500K refund operations/day, a much lower-volume, non-latency-critical path.
- Audit log retention: financial/regulatory requirements typically mandate multi-year retention (often 7 years) of transaction records — a very different storage lifecycle than, say, view_events from Day 22, which can be aggressively pruned.
- Disputes/chargebacks: a small fraction of transactions (typically well under 1%), but each one requires a full, reconstructable history — this is a low-volume, high-stakes-per-record workload, the opposite shape from most systems in this course.

## API sketch

```
POST /payments/charge      { order_id, amount, payment_method_token, idempotency_key }
  -> { payment_id, status: "pending"|"succeeded"|"failed" }

GET  /payments/{id}                          -> { status, amount, order_id, history[] }
POST /payments/{id}/refund { amount?, reason, idempotency_key }
  -> { refund_id, status }

POST /webhooks/payment-provider               -- inbound async status updates from the provider
GET  /payments/{id}/audit-log                 -> { events[] }   -- immutable event history
```

Note `payment_method_token`, not a raw card number — the API never accepts raw PANs (Primary Account Numbers) from your own backend; tokenization happens client-side against the payment provider directly (see PCI compliance below).

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

`payment_events` is deliberately append-only and immutable — never `UPDATE` a row in it, only `INSERT`. This is the audit trail, and it's what makes disputes and debugging possible: the current `payments.status` is a derived/cached summary, but `payment_events` is the actual source of truth for "what happened, in what order."

## High-level architecture

```
Checkout service --> POST /payments/charge (idempotency_key from Day 24's checkout flow)
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

## Component deep dives

**Idempotency, end to end.** This is the single most important property in the whole system, and it has to hold at two layers: between your checkout client and your payment service (the `idempotency_key` from Day 24, enforced via the `UNIQUE` constraint on `payments.idempotency_key` — a retried `/payments/charge` call with the same key returns the existing payment record instead of creating a new charge), and between your payment service and the external provider (pass that same idempotency key through to the provider's API — Stripe, Adyen, and similar providers natively support this, guaranteeing that even if your service's own retry logic double-sends the outbound call, the provider only charges once). Two layers, because a failure can happen on either side of that boundary, and each side needs its own protection.

**Why webhooks exist, not just synchronous responses.** Card charges often do resolve synchronously (approve/decline within the request). But many payment methods and flows are inherently asynchronous — bank transfers (ACH, SEPA) settle over days, 3D-Secure authentication requires an out-of-band customer step, and disputes/chargebacks are initiated by the card network days or weeks later. The system has to treat "final settlement status" as something that can arrive well after the initial request, via a webhook the provider calls back into your system. Webhook handlers must themselves be idempotent (providers routinely retry webhook delivery) and should verify the request's authenticity (signature verification against the provider's signing secret) before trusting the payload — an unauthenticated webhook endpoint is a direct path to payment fraud.

**PCI compliance shaping the architecture, not just a checkbox.** The single biggest architectural consequence of PCI-DSS: your own backend should ideally never touch raw card numbers (PANs) at all. Card data is tokenized client-side, directly against the payment provider's SDK/hosted fields (e.g., Stripe Elements, Stripe.js) — your frontend collects card details into an iframe/SDK component controlled by the provider, which returns an opaque token; that token, not the raw card number, is what flows through `payment_method_token` in the API above. This dramatically reduces your PCI compliance scope (you're handling tokens, not cardholder data) and is why "just store the card number in our DB" is never the right answer in a payments design interview — say this explicitly, it's a strong signal.

**Handling failed payments.** A decline (insufficient funds, fraud flag, expired card) is a normal, expected outcome, not a system failure — write it to `payment_events`, set `payments.status = failed`, and let the checkout flow (Day 24) release its inventory reservation and prompt the user to retry with a different payment method. Distinguish declines (definitive, provider says no) from ambiguous failures (timeout, no response) — the latter requires querying the provider's status endpoint with the original idempotency key before deciding whether to retry, exactly as covered in Day 24, never blindly re-attempting the charge.

**Refunds and disputes.** A refund is its own idempotent, auditable operation (`POST /payments/{id}/refund` with its own idempotency key) — never mutate the original `payments` row's amount; instead insert a `refunds` row and let `payments.status` become `refunded`/`partially_refunded`, preserving the original charge event intact for audit purposes. Disputes/chargebacks are typically *initiated by the payment network* (not your own API) and arrive as a webhook event — the system needs a `disputes` table and workflow to track evidence submission and outcome, and critically, the `payment_events` append-only log is what lets you reconstruct the full timeline of a disputed transaction on demand, which is often a contractual/regulatory requirement, not a nice-to-have.

## Scaling & trade-offs

| Decision | Benefit | Cost |
|---|---|---|
| Idempotency keys at two layers (client-to-service, service-to-provider) | Eliminates double-charge risk from retries at either boundary | Requires careful key scoping and a durable idempotency-key store |
| Append-only `payment_events`, derived `payments.status` | Full audit trail, supports dispute reconstruction, never loses history | More storage than mutating one row in place; queries need to consider "latest event" logic |
| Tokenization at the client, never touching raw PANs server-side | Drastically reduces PCI compliance scope | Frontend must integrate the provider's SDK/hosted fields rather than a plain form |
| Async webhook handling for final settlement status | Correctly models genuinely asynchronous payment methods (ACH, 3DS, disputes) | Webhook handlers must be idempotent and signature-verified; adds a second ingestion path beyond the synchronous API |

## Likely follow-up questions — with answers

**Q: Your service calls the payment provider's charge API, but the network times out before you get a response. What do you do?**
A: Never blindly retry the raw charge — the original call may have succeeded on the provider's side even though your service never saw the response. Instead, retry using the same idempotency key (the provider recognizes it and returns the existing result rather than charging again), or explicitly query the provider's payment-status endpoint for that idempotency key/reference before deciding the outcome. Only after confirming genuine non-completion should you mark the payment failed and release the checkout's inventory reservation.

**Q: Why not just store `payments.status` and skip the separate `payment_events` audit log?**
A: Because a single mutable status field destroys history — you can no longer answer "what happened, in what order, and when" once a row has been overwritten multiple times (pending → succeeded → refunded, say). Disputes, regulatory audits, and debugging all require reconstructing the full sequence of events for a transaction, not just its current state. The append-only event log is the actual source of truth; the status field on `payments` is a convenience projection derived from it.

**Q: A payment provider sends you a webhook, but you can't tell if it's genuinely from them or spoofed. How do you handle that?**
A: Verify the webhook's cryptographic signature against the provider's published signing secret before processing the payload at all — every major provider (Stripe, Adyen, etc.) signs webhook payloads specifically so receivers can authenticate them. An unverified webhook endpoint that blindly trusts incoming "payment succeeded" events is a direct fraud vector (an attacker could POST a fake success event to your endpoint to unlock an order without paying) — signature verification is a mandatory first step, not an optional hardening measure.

## Key takeaways

- Idempotency has to be enforced at two boundaries — client-to-your-service and your-service-to-provider — because a retry can originate on either side of that call.
- Append-only `payment_events` (never mutated, only inserted) is the actual source of truth; any single mutable status field is a derived convenience and cannot support audits or disputes on its own.
- PCI compliance is an architectural decision, not a checklist item — tokenizing card data client-side, so raw PANs never touch your backend, is the answer that signals real payments experience in an interview.
- Webhooks exist because settlement is genuinely asynchronous for many payment methods (ACH, 3DS, disputes) — webhook handlers must be idempotent and signature-verified.
- Ambiguous failures (timeouts) are resolved by querying the provider's status with the original idempotency key, never by blind retry — this is the same pattern as Day 24's checkout, applied at the payment-provider boundary specifically.
- This system explicitly prioritizes correctness and auditability over throughput — say that trade-off out loud when a follow-up pushes on scaling, since it explains why you wouldn't relax consistency here the way you would for, say, a view counter.
