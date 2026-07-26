---
kind: lesson
id_key: interview-prep-45/day-42
course: interview-prep-45
section: final-prep
section_title: "Weakness Focus & Final Prep"
section_position: 8
title: "Light Practice and Rest"
position: 42
estimated_minutes: 240
source:
    - 45-day-interview-roadmap.md
---

Today is a **taper day**, not a study day. In endurance sports, athletes cut training volume in the final days before competition — the work is already banked, and what's left is protecting it. Same principle here: new material this close to interviews doesn't stick, and cramming raises cortisol without raising recall. The goal for the next three blocks is to keep your hands warm, run one clean final review pass over everything you've built in 41 days, and then deliberately stop.

## Block 1 (60-90 min): Light Practice

The rule for today's problems: **solve things you already know how to solve.** This is not the day to attempt a problem type you're shaky on — that's what Day 36-41 were for. Picking a fight with an unfamiliar problem today just seeds doubt the night before interviews start.

### 3 easy problems — one per pattern family

Pick one from each row below. Prefer problems you've already solved earlier in this course over brand-new ones — you're rehearsing retrieval, not discovering new logic.

| Pattern | Signal to recognize it | Core idea |
|---|---|---|
| Array / Hashing | "find pair/duplicate/frequency" | One pass with a hash map trading space for O(1) lookup |
| Two Pointers / Sliding Window | "subarray/substring satisfying a condition", sorted array | Move a window's edges instead of re-scanning |
| Tree/Graph BFS-DFS | "shortest path in unweighted graph" (BFS) / "explore all paths, connectivity" (DFS) | Queue for level-by-level, recursion/stack for depth-first |

Time-box each to 15-20 minutes including a clean writeup. If any of the three takes longer than that, it's not actually in your "strong" bucket — flag it, but don't chase it today.

### 2 system designs — 15-minute speed rounds

Speed, not depth, is the point today. For each:

1. State functional + non-functional requirements out loud (60 seconds).
2. Draw the high-level box diagram (client → LB → service → cache → DB) (3-4 minutes).
3. Name the ONE hardest part of the system and say in two sentences how you'd approach it — don't actually solve it (2 minutes).
4. Stop. Move to the next design.

This drills the skill interviewers actually grade in the first 15 minutes: can you structure a design under time pressure without freezing on where to start.

**Verify you're actually strong here:** if you needed the full 20 minutes for an "easy" problem, or you hesitated more than 5 seconds on where to start a design, that's signal — not something to fix today, just something to be aware of walking in.

## Block 2 (~90 min): Final Prep — the Last Full Review Pass

This is the highest-value block of the day: one clean sweep across everything, so nothing you've learned is sitting stale in a doc you haven't opened in three weeks.

### Review all STAR stories

Recap the structure before you read your stories, so you're grading against the right rubric:

| Letter | What it covers | Common failure |
|---|---|---|
| Situation | 1-2 sentences of context — company, team, timeline | Rambling for 90 seconds before getting to the point |
| Task | What you specifically were responsible for | Describing the team's goal instead of your role |
| Action | What YOU did, step by step | Using "we" throughout — interviewers can't score a team's actions against you |
| Result | Measurable outcome + what you learned | No number, no follow-up learning — just "it worked out" |

Make sure your bank covers every category an interviewer is likely to probe. If any row below is empty, that's a gap to fill today, not on interview morning:

- [ ] Conflict with a teammate or manager
- [ ] A project that failed or shipped late
- [ ] Leading without formal authority
- [ ] Working with ambiguous or changing requirements
- [ ] Disagreeing with a decision and either pushing back or committing
- [ ] A tight deadline you had to hit
- [ ] Mentoring or unblocking someone else
- [ ] Cross-team or cross-function collaboration
- [ ] Deepest technical challenge you've solved
- [ ] Why this company / why this role

**Verify you're actually strong here:** tell each story out loud, cold, in under 2 minutes, ending on a concrete measurable result. If you're padding with backstory or the result is vague ("it went well"), rewrite that story now.

### Review all system designs

Run down the canonical list. For each, you should be able to name the ONE hardest part from memory without opening notes:

| System | The hard part |
|---|---|
| URL shortener | Collision-free ID generation at scale (base62 counter vs. hash) |
| Chat / messaging | Message ordering + delivery guarantees across devices |
| Twitter / news feed | Fan-out on write vs. fan-out on read for celebrity accounts |
| Uber / ride-sharing | Real-time geospatial matching (geohash / quadtree) at scale |
| Rate limiter | Distributed counting without a single point of failure |
| Payment system | Idempotency + exactly-once semantics on a network that retries |
| Notification system | Fan-out to millions of devices + delivery/read tracking |
| Web crawler | Politeness (rate per domain) + dedup at web scale |
| Search autocomplete | Trie/prefix index with ranking, refreshed without downtime |
| Distributed cache | Consistent hashing + cache invalidation strategy |

**Verify you're actually strong here:** for each system, say the hard part out loud in one sentence, no notes. If you blank on more than two or three, pick those for a 15-minute deep-dive tonight — not tomorrow, tonight, while it's still light-practice day and not interview day.

### Review common technical questions

Rapid-fire pass across all four tracks. Read each question, answer out loud in one breath, then check yourself:

**Backend**
- *WSGI vs. ASGI?* — WSGI is synchronous, one thread per request; ASGI supports async/await and long-lived connections (websockets, SSE).
- *How do you avoid N+1 queries in Django?* — `select_related` for FK/one-to-one (SQL JOIN), `prefetch_related` for reverse FK/M2M (separate query + Python-side join).
- *FastAPI dependency injection — why does it matter?* — `Depends()` makes auth, DB sessions, and pagination testable/mockable and keeps route handlers thin.
- *When do you reach for a Postgres index vs. a Redis cache?* — Index when the query pattern is stable and you need correctness/consistency; cache when the same read repeats and slight staleness is acceptable.
- *Cache-aside vs. write-through?* — Cache-aside: app checks cache, falls back to DB, populates cache on miss (simpler, risk of stale data). Write-through: every write updates cache and DB together (always fresh, more write latency).

**Frontend**
- *Why does `key={index}` break on reorder?* — React matches siblings by key across renders; an index key shifts identity when items move, so state (like a focused input) attaches to the wrong row.
- *When does `useMemo` actually help?* — Only when the computed value is expensive AND identity-sensitive (passed to `React.memo` children or as an effect dependency) — otherwise the comparison overhead isn't worth it.
- *`unknown` vs `any` in TypeScript?* — `any` disables type checking entirely; `unknown` still requires a narrowing check before use, so mistakes surface at compile time.

**DSA**
- *When is a greedy solution valid?* — When the problem has the optimal-substructure + no-regret property (a locally optimal choice never gets undone later); if you can't prove that, use DP instead.
- *Time complexity of building a heap from an array?* — O(n), not O(n log n) — because most nodes are near the bottom and sift down a short distance (amortized analysis, not naive per-node bound).
- *When does BFS beat DFS?* — Whenever "shortest path" or "fewest steps" in an unweighted graph is the question — BFS explores by distance layer, DFS does not.

**Verify you're actually strong here:** if you paused more than 3-4 seconds on any answer above, that's not a gap to close today — just make a mental note of it as a likely follow-up question to expect.

## Block 3 (~30-45 min): Rest — Actually Do This

This is not filler. Sleep before a high-stakes performance improves working memory, pattern recall, and emotional regulation more than any additional hour of study would — the taper only works if you actually stop.

Concrete rules for tonight:

- **No new material after this block.** If you find a gap during Block 2, write it down and move on — do not chase it into the evening.
- **Caffeine cutoff:** nothing after early afternoon; it has a 5-6 hour half-life and will fight your sleep tonight.
- **Screens off 30-60 minutes before bed.** Read, stretch, or do something boring on purpose.
- **Skip interview-horror-story forums tonight.** Reading someone else's bad experience right before bed does nothing but load anxiety with no offsetting benefit.
- **Light movement** — a walk, stretching — lowers cortisol better than sitting with your notes one more time.
- **One calming ritual** you actually enjoy: a show, music, a call with someone who isn't also stressed about interviews.

If your mind keeps circling back to a specific weak spot, write one sentence about it on paper and close the notebook. Externalizing the worry measurably reduces rumination — you don't have to solve it to stop thinking about it.

## Key takeaways

- Today is a taper: reduce volume, don't add new material — recall of what you already know beats last-minute discovery.
- Light practice problems should come from your strong patterns; the point is confidence and retrieval speed, not new learning.
- The STAR review isn't complete until every major category (conflict, failure, leadership, ambiguity, mentoring, cross-team) has a ready 2-minute story with a measurable result.
- For system design review, you only need to recall the ONE hardest part of each canonical system from memory — that's the signal interviewers actually probe for.
- Sleep and cortisol reduction the night before interviews measurably improve recall and composure — treat rest as part of the prep, not a break from it.
- Any gap found today gets written down, not chased — fix small things tonight if time allows, then stop.
