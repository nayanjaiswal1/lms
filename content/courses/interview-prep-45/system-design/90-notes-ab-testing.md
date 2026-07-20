---
kind: lesson
id_key: interview-prep-45/note-ab-testing
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Notes: A/B Testing Fundamentals"
position: 90
estimated_minutes: 15
source:
    - interview-prep-notes.md
---

A/B testing doesn't appear anywhere else in the course, but it's a recurring follow-up to component-design questions ("how would you know if this change actually helped?") and comes up directly in senior/staff loops that blend system design with product sense.

## What it is and why interviewers ask

An A/B test randomly splits users into two (or more) groups — a control seeing the current experience and a treatment seeing a change — and compares a target metric between groups to determine whether the change causally improved it. Interviewers ask about it to check whether you can reason about **causality vs correlation**: a metric moving after a launch doesn't prove the launch caused it (seasonality, concurrent changes, and selection bias can all produce the same signal), while a properly randomized A/B test isolates the change as the cause.

## Core design decisions

**Randomization unit.** Almost always assign by user ID (hashed into a bucket), not by session or request — a user should see a consistent experience across visits, or the test measures confusion/inconsistency instead of the actual change. Hash the user ID with a fixed salt per experiment (`hash(user_id + experiment_name) % 100`) so bucket assignment is deterministic and reproducible without needing to store an assignment per user.

**Sample size and test duration.** Before launching, compute the minimum sample size needed to detect the smallest effect size worth caring about, given a target statistical power (typically 80%) and significance level (typically 5%). Running a test too short risks a false negative from noise; running it too long wastes an opportunity cost of exposing users to a losing variant. A one-week minimum is common even if sample size is reached faster, to average out day-of-week effects (weekday vs weekend behavior differs for most consumer products).

**Primary metric vs guardrail metrics.** Pick one primary metric the test is designed to move (e.g. checkout conversion rate) and a small set of guardrail metrics that must not regress (e.g. page load time, error rate, revenue per user) — a test can "win" on the primary metric while quietly breaking something else, and guardrails catch that.

**Statistical significance vs practical significance.** A result can be statistically significant (unlikely to be noise) but practically meaningless (a 0.01% lift not worth the added complexity) — or the reverse, with a real but noisy-looking effect that a longer test would confirm. Report both the p-value/confidence interval and the actual effect size, not just "significant: yes/no."

## System design considerations

```
User request
     |
     v
Experiment Assignment Service  <-->  Experiment Config Store (which experiments are live, split %)
     |
     v (bucket: control | treatment, deterministic via hashed user_id)
Application serves the appropriate variant
     |
     v
Event Logging (impressions + downstream metric events) --> Analytics Pipeline --> Dashboard
```

- **Assignment must be fast and available** — it sits on the critical path of every request that touches an experiment, so it's typically a local hash computation (no network call) rather than a lookup against a remote service, with experiment configs cached/pushed to app servers periodically rather than fetched per-request.
- **Mutual exclusion between overlapping experiments.** Running many experiments simultaneously risks interaction effects (experiment A's treatment interacts badly with experiment B's treatment for the same user). Solve with **layers**: partition traffic into independent layers where experiments in the same layer are mutually exclusive (a user is in exactly one experiment per layer) but experiments in different layers can run concurrently.
- **Logging must tie the assignment to the outcome.** Every metric event needs to be attributable back to which variant the user was in at the time — log the experiment/variant alongside (or joinable to) the business event, not just aggregate counts, so the analysis can be re-sliced later (by platform, region, user segment) without re-running the experiment.
- **Ramp-up, not instant 50/50.** Launch a new experiment at a small treatment percentage (e.g. 1%) first to catch catastrophic bugs cheaply, then ramp to the full test split once basic health is confirmed — this is the same "canary" instinct as a canary deployment, applied to experiment rollout.

## Common pitfalls

- **Peeking** — checking results repeatedly and stopping as soon as they look significant inflates the false-positive rate (each peek is another chance to catch a random fluctuation) — decide the sample size/duration in advance and don't stop early based on interim results, unless using a sequential-testing method designed to allow it.
- **Novelty effect** — a change might perform well simply because it's new and users are curious/exploring, with the effect fading after the initial period; a too-short test can mistake this for a durable improvement.
- **Sample Ratio Mismatch (SRM)** — if the actual observed split (e.g. 48/52) deviates significantly from the intended split (50/50), something is broken in the assignment/logging pipeline, and the test's results shouldn't be trusted until the mismatch is root-caused — this is a standard automated sanity check before reading any other result.

## Key takeaways

- A/B testing isolates causation by randomizing users into control/treatment groups — deterministic, salted hash-based assignment on user ID keeps the experience consistent per user without a stateful lookup.
- Define a single primary metric plus guardrail metrics before launch; report effect size alongside statistical significance, not just a pass/fail p-value.
- At scale, use independent experiment "layers" for mutual exclusion between concurrent tests, ramp new experiments up gradually, and always check for Sample Ratio Mismatch before trusting the results.
- Peeking at results early and stopping based on them inflates false positives — commit to a sample size/duration in advance.
