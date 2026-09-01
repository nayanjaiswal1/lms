---
kind: lesson
id_key: interview-prep-45/day-39
course: interview-prep-45
section: final-prep
section_title: "Weakness Focus & Final Prep"
section_position: 8
title: "Final Mock Interviews"
position: 39
estimated_minutes: 240
source:
    - 45-day-interview-roadmap.md
---

Six full mock interviews across two days, each run as close to the real thing as you can make it: a timer, a stranger or recording if possible, no pausing to look things up, no restarting. This lesson gives you the rubric to grade yourself against for each mock type, because "that felt okay" is not useful feedback.

## Day 2 of Mocks, Morning: DSA, System Design, Behavioral

### Mock 1: DSA (30 min)

Pick a medium-difficulty problem you haven't seen (ask a friend to pick, or use a randomizer on a problem list). Run the full interview shape:

1. Restate the problem in your own words (30 sec). This confirms you understood it.
2. Ask 1-2 clarifying questions (input size, duplicates allowed, negative numbers).
3. State a brute-force approach and its complexity out loud before optimizing.
4. Code the optimized approach, narrating as you go.
5. Walk through one example by hand.
6. State final time/space complexity unprompted.

**Grade yourself:**

| Signal | Pass bar |
|---|---|
| Silence between "read problem" and "start talking" | Under 30 seconds |
| Communication while coding | Continuous, not silent typing for 5+ min |
| Complexity stated | Unprompted, correct |
| Edge cases | Mentioned before or during coding, not only when asked |
| Bug recovery | Notices and fixes own bugs while testing, doesn't need a hint |

### Mock 2: System Design (40 min)

Pick a random system from your practiced list, not one you'd choose. Full six-step run: requirements, capacity, API, high-level, deep dive, bottlenecks.

**Grade yourself:**

| Signal | Pass bar |
|---|---|
| Time on requirements+capacity | Under 10 min total, don't over-invest here |
| Drives the conversation | You propose the next step, interviewer doesn't have to prompt "what about X" |
| Deep dive depth | One component gets real detail (data model, algorithm, or protocol), not just boxes |
| Tradeoffs stated | At least 2 explicit "I chose X over Y because Z" moments |
| Handles a curveball | If the interviewer changes a requirement (10x scale, add a feature), you adapt the existing design instead of restarting |

### Mock 3: Behavioral (20 min)

Full interview simulation: 4-5 questions pulled from your story bank but asked out of order, plus at least one you don't have a prepped story for (forces you to structure STAR on the fly).

**Grade yourself:**

| Signal | Pass bar |
|---|---|
| Each answer | Under 2 minutes, STAR-shaped |
| Filler words | Near zero (see Day 37 recording practice) |
| Specificity | Names a real metric, decision, or outcome instead of a generic one ("I improved performance" vs. "I cut p99 latency from 800ms to 140ms") |
| Follow-up handling | Answers a "why" or "what would you do differently" follow-up without repeating the original answer |

## Day 2 of Mocks, Afternoon: Frontend, Backend, Behavioral

### Mock 4: Frontend (30 min, build a component)

Build a small interactive component live (autocomplete search box, paginated table, or a debounced filter list) with a stranger or timer watching. This tests React fundamentals under pressure, not exotic knowledge.

**Grade yourself:**

| Signal | Pass bar |
|---|---|
| State shape | Chosen deliberately (what's local state vs. derived) before coding starts |
| Effects | Correct dependency arrays, cleanup functions where needed (debounce timers, aborted fetches) |
| Edge cases | Empty state, loading state, error state all handled, not just the happy path |
| Explaining tradeoffs | Can say why you chose controlled vs. uncontrolled, or why you debounced instead of throttled |

### Mock 5: Backend (30 min, deep technical questions)

No coding, just pure depth-of-knowledge questioning on your stack (Django/FastAPI, PostgreSQL, Redis). Expect chains like: "how does a DB index actually work" -> "when would an index *hurt* write performance" -> "how would you find a slow query in production."

**Grade yourself against these actually-asked question types:**

- Explain the N+1 query problem and how you'd catch it before it ships (`select_related`/`prefetch_related`, query count assertions in tests, APM).
- Explain optimistic vs. pessimistic locking and when you'd choose each.
- Explain what happens in PostgreSQL when two transactions update the same row concurrently (row-level locks, potential deadlock, isolation levels).
- Explain Redis eviction policies and why choosing the wrong one silently breaks a cache-as-source-of-truth mistake.
- Explain how you'd add rate limiting to an API without a shared datastore vs. with one.

If you can't answer any of these in under 90 seconds without a "um, let me think," that's your evening review target.

### Mock 6: Behavioral (20 min, situational questions)

Different from Mock 3: these are hypotheticals, not past-experience stories. "Your teammate keeps merging code without tests, what do you do?" "You disagree with your manager's technical decision, walk me through how you handle it." These test judgment, not memory.

**Grade yourself:**

| Signal | Pass bar |
|---|---|
| Structure | States the principle first ("I'd raise it directly and early"), then the specific steps |
| Balance | Shows both directness and collaboration, neither pure compliance nor pure confrontation |
| Real anchor | Ties back to an actual past experience if you have one, even for a hypothetical |

## Review and Rest (30-40 min)

- Go through all six grade tables above. Circle every row where you didn't hit the pass bar. That's your actual punch list, not a vague "I need to practice more."
- Write down the **one** most important fix for tomorrow (Day 40) per track (DSA, system design, backend/frontend, behavioral). One fix each, not five: you have limited time left.
- Relax and rest. Six mocks in a day is genuinely tiring, and the recovery is part of the plan.

**Verify you're actually strong here:** for each track, answer out loud: "if I had this exact mock again right now, what's the one thing I'd change?" If you can't name one specific thing, you weren't grading yourself honestly during the mock. Go back to the tables above and be stricter.
