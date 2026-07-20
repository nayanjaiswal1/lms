---
kind: lesson
id_key: interview-prep-45/day-32
course: interview-prep-45
section: mock-interviews
section_title: "Mock Interviews"
section_position: 7
title: "Day 32 — Mock Interviews 7–9: DP, Backend, Behavioral"
position: 32
estimated_minutes: 240
source:
    - 45-day-interview-roadmap.md
---

Three mocks today: a hard DP problem, a backend Q&A round, and STAR-method behavioral drilling. Run every segment on a hard timer, speak your reasoning out loud, and don't check any reference answer until you've committed to your own.

## Run of show

| Time | Segment |
|---|---|
| 0:00–0:35 | Mock 7: DSA — Longest Increasing Subsequence, DP + binary search (35 min) |
| 0:35–0:45 | Break |
| 0:45–1:15 | Mock 8: Backend Deep Dive — Django/FastAPI questions (30 min) |
| 1:15–1:25 | Break |
| 1:25–1:50 | Mock 9: Behavioral — STAR practice, 4 prompts (25 min) |
| 1:50–2:15 | Score against rubric, write debrief |
| 2:15–3:00 | Extra practice: Word Break, Coin Change, or Edit Distance (pick one, 40 min) |
| 3:00–4:00 | Buffer — re-run your weakest segment cold |

## Mock Interview 7: DSA — Longest Increasing Subsequence (35 minutes)

**Problem:** [Longest Increasing Subsequence (LeetCode 300)](https://leetcode.com/problems/longest-increasing-subsequence/). Given an integer array `nums`, return the length of the longest strictly increasing subsequence.

```
Input: nums = [10,9,2,5,3,7,101,18]
Output: 4   # [2,3,7,101]
```

**Instructions:** solve with both DP (O(n²)) and binary search (O(n log n)), and explain both approaches — that comparison is the actual ask.

**Clarifying hints:**
- "Strictly increasing or non-decreasing?" — Strictly increasing.
- "Subsequence, not subarray — elements don't need to be contiguous?" — Correct, confirm this before coding since it changes the whole approach.
- "Return the length only, or the subsequence itself?" — Length only here; mention that reconstructing the actual subsequence requires tracking parent pointers.

Budget: 3 min clarify, 7 min discuss both approaches, 20 min code both, 5 min test.

#### Reference solution

```python
import bisect

def length_of_lis_dp(nums: list[int]) -> int:
    """O(n^2) DP: dp[i] = length of LIS ending at index i."""
    if not nums:
        return 0
    dp = [1] * len(nums)
    for i in range(len(nums)):
        for j in range(i):
            if nums[j] < nums[i]:
                dp[i] = max(dp[i], dp[j] + 1)
    return max(dp)


def length_of_lis_binary_search(nums: list[int]) -> int:
    """O(n log n): maintain 'tails', tails[k] = smallest possible tail of an
    increasing subsequence of length k+1. tails stays sorted, so binary search
    finds the insertion point."""
    tails: list[int] = []
    for n in nums:
        pos = bisect.bisect_left(tails, n)
        if pos == len(tails):
            tails.append(n)
        else:
            tails[pos] = n
    return len(tails)


if __name__ == "__main__":
    nums = [10, 9, 2, 5, 3, 7, 101, 18]
    assert length_of_lis_dp(nums) == 4
    assert length_of_lis_binary_search(nums) == 4
    assert length_of_lis_binary_search([]) == 0
    assert length_of_lis_binary_search([7, 7, 7]) == 1
    print("ok")
```

**What to explain out loud:** the DP approach is the intuitive one — `dp[i]` answers "longest increasing subsequence ending exactly at `i`," built from all valid `j < i`. It's O(n²) and easy to derive but not optimal. The binary-search approach reframes the problem: `tails[k]` tracks the smallest tail value achievable for any increasing subsequence of length `k+1`. `tails` is always sorted (this needs a one-line proof if pushed: a smaller tail for the same length can only help extend further, so the array is monotonic by construction), which is exactly what makes binary search valid. Critically, `tails` does *not* hold an actual subsequence — it's a greedy invariant — say this explicitly, it's the detail interviewers use to check real understanding versus memorized code.

## Mock Interview 8: Backend Deep Dive — Django/FastAPI (30 minutes)

**Instructions:** set a 30-minute timer. This is a rapid Q&A round, not a coding round — answer each question out loud in 3–5 minutes as if explaining to a teammate, then compare against the reference answer.

**Question 1: Explain the Django request lifecycle.**

*Clarifying hint an interviewer might add:* "Walk it from the WSGI server to the response, mention where middleware fits."

*Reference answer:* A request hits the WSGI/ASGI server (e.g. gunicorn), which hands it to Django's `WSGIHandler`. Django runs it through the middleware stack top-down (`SecurityMiddleware`, `SessionMiddleware`, `AuthenticationMiddleware`, etc.), each able to short-circuit and return early. The URL resolver matches the path against `urlpatterns` to find the view. The view function/class runs — typically: parse request, query the ORM, build a response (often via a serializer in DRF). The response then flows back up through the middleware stack in reverse order (each middleware gets a chance to modify the response), and finally goes back to the WSGI server. Key point to mention: middleware order matters and is a common source of bugs (e.g. `AuthenticationMiddleware` must run before anything that reads `request.user`).

**Question 2: How does async work in FastAPI?**

*Reference answer:* FastAPI is built on Starlette and ASGI, so it supports both `async def` and regular `def` route handlers. `async def` handlers run directly on the event loop — ideal for I/O-bound work (DB calls with an async driver, HTTP calls to other services) since the loop can serve other requests while waiting on I/O. Regular `def` handlers are automatically run in a thread pool executor so they don't block the event loop even though they're synchronous — this is what lets you mix a legacy sync ORM call into an otherwise async app safely. The trap to name: calling a *blocking* library (e.g. `requests`, a sync DB driver) inside an `async def` handler blocks the entire event loop for every concurrent request, which is worse than just using `def` and letting FastAPI thread-pool it. Always match the handler type to whether the work inside it is actually async-capable.

**Question 3: How would you optimize a slow query?**

*Reference answer:* Start with `EXPLAIN ANALYZE` (Postgres) to see the actual query plan and where time is spent — sequential scan vs index scan, nested loop vs hash join, row estimate vs actual rows. Common fixes in order of likelihood: add an index on the filtered/joined column (check it's actually being used, not just present — an index on a low-cardinality column often gets ignored by the planner); fix an N+1 query pattern (Django: use `select_related` for forward FK/O2O joins, `prefetch_related` for reverse FK/M2M to batch what would otherwise be one query per row); avoid `SELECT *` when only a few columns are needed; check if the query can be paginated instead of loading the full result set; consider a covering index if the query is read-heavy and index-only scans would avoid a table lookup entirely. Mention you'd verify any fix against the actual query plan afterward, not just assume it helped.

**Question 4: Explain database transactions.**

*Reference answer:* A transaction groups multiple statements into a single atomic unit — either all commit or all roll back, no partial state. Explain ACID briefly: Atomicity (all-or-nothing), Consistency (moves the DB from one valid state to another, respecting constraints), Isolation (concurrent transactions don't see each other's uncommitted changes — governed by isolation level: read committed, repeatable read, serializable, each trading consistency guarantees for concurrency/performance), Durability (once committed, survives a crash). In Django, `with transaction.atomic():` wraps a block; an unhandled exception inside triggers a rollback. Mention a concrete failure mode: without a transaction, a multi-table write (e.g. debit one account, credit another) can partially fail and leave the data inconsistent — that's the exact scenario transactions exist to prevent, and it's worth naming explicitly since it shows you understand *why*, not just the syntax.

## Mock Interview 9: Behavioral — STAR Practice (25 minutes)

**Instructions:** set a 25-minute timer, roughly 5–6 minutes per prompt including a beat to plan the STAR structure before speaking. Use a different real story for each — reusing the same anecdote for every prompt is a red flag interviewers notice immediately.

**Prompt 1: Conflict resolution (5 minutes)**
Situation/Task: what was the disagreement and what was at stake. Action: what you specifically did to resolve it — did you escalate, compromise, gather data to settle it objectively, have a direct conversation. Result: the outcome and the relationship afterward. Weak answers avoid naming the actual disagreement or paint the other person as simply wrong; strong answers show you understood the other side's position before resolving it.

**Prompt 2: Technical challenge (5 minutes)**
Pick a genuinely hard problem, not routine work. Be ready to go deep on the technical specifics if pushed — an interviewer testing this answer will ask "why did you choose that approach over X."

**Prompt 3: Leadership (5 minutes)**
Leadership doesn't require a title — leading a project, mentoring someone, driving a decision without formal authority all count. Action should show initiative and influence, not just "I was the lead so I assigned tasks."

**Prompt 4: Failure (5 minutes)**
This is the one candidates fumble most by picking a fake failure ("I worked too hard") or being too vague to be credible. Pick a real mistake with real consequences. The Result section must include what changed in how you work afterward — that's what interviewers are actually listening for, evidence of growth, not the failure itself.

**Reference approach for all four:** allocate roughly 20% Situation/Task, 60% Action, 20% Result within each 5-minute slot. The Action section is where most candidates under-invest — "I fixed it" is not an action, "I profiled the service, found the lock contention was in the connection pool, and split it into per-shard pools" is. If you can't fill 3 minutes of concrete action detail on a story, it's the wrong story — pick one with more substance.

**Extra practice — Word Break, Coin Change, Edit Distance.** All three are 1D/2D DP problems in the same family as today's LIS problem. Use the buffer block to solve one cold: Word Break is a 1D DP over string prefixes (`dp[i]` = can `s[:i]` be segmented using the dictionary), Coin Change is 1D DP over amounts (`dp[a]` = min coins to make amount `a`), Edit Distance is 2D DP over two string prefixes. Recognizing "this is DP over prefixes/amounts" as fast as possible is the actual skill being drilled.

## Scoring rubric

**Mock 7 — DSA (Longest Increasing Subsequence)**
- Correctly implemented the O(n²) DP solution: /5
- Correctly implemented and explained the O(n log n) binary-search solution, including why `tails` stays sorted: /5
- Clearly contrasted the two approaches' complexity and trade-offs: /5
- Handled edge cases (empty array, all equal elements, strictly decreasing array): /5

**Mock 8 — Backend Deep Dive**
- Django request lifecycle answer covered middleware order and where the view fits: /5
- Async/FastAPI answer correctly distinguished `async def` vs `def` handling and named the blocking-call trap: /5
- Query optimization answer led with `EXPLAIN ANALYZE` and named at least two concrete fixes (index, N+1): /5
- Transactions answer covered ACID and gave a concrete failure scenario transactions prevent: /5

**Mock 9 — Behavioral (STAR)**
- Conflict resolution: showed the other side's perspective, not one-sided: /5
- Technical challenge: survived a hypothetical "why that approach" follow-up: /5
- Leadership: demonstrated initiative/influence, not just a title: /5
- Failure: was a real mistake with a real consequence and a stated change in behavior afterward: /5

## Debrief

For the DP problem, log which sub-pattern you recognized slowly (prefix DP, interval DP, knapsack-shaped) — LIS-family problems recur constantly, and the fix is pattern recognition speed, not re-deriving recurrences from scratch each time. For the backend round, note any question where your answer was syntax-only without the "why" — that's the gap technical Q&A rounds are designed to expose. For behavioral, flag any story where the Action section ran under a minute; that story needs a rewrite with more concrete detail before your next mock. Everything scored 3/5 or below goes on tomorrow's warm-up.

## Today's checklist

- [ ] Mock 7: solved LIS with DP approach
- [ ] Mock 7: solved LIS with binary search approach
- [ ] Mock 7: explained both approaches out loud
- [ ] Mock 7 extra: attempted Word Break, Coin Change, or Edit Distance
- [ ] Mock 8: answered Django request lifecycle
- [ ] Mock 8: answered async in FastAPI
- [ ] Mock 8: answered slow query optimization
- [ ] Mock 8: answered database transactions
- [ ] Mock 9: answered conflict resolution using STAR (5 min)
- [ ] Mock 9: answered technical challenge using STAR (5 min)
- [ ] Mock 9: answered leadership using STAR (5 min)
- [ ] Mock 9: answered failure using STAR (5 min)
- [ ] Scored every mock against the rubric and logged debrief notes
