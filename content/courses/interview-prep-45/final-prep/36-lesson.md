---
kind: lesson
id_key: interview-prep-45/day-36
course: interview-prep-45
section: final-prep
section_title: "Weakness Focus & Final Prep"
section_position: 8
title: "Weakness Focus — DP, System Design, Frontend"
position: 36
estimated_minutes: 240
source:
    - 45-day-interview-roadmap.md
---

Today is a targeted-repair day, not a survey day. You already know the easy 80% of DP, system design, and frontend. This is about the 20% that's actually failing you in interviews — string-matching DP, your three weakest system designs, and whatever React concept you keep hand-waving through. Three 80-minute blocks, each ending with a concrete self-check.

## Block 1 (80 min): DP Weakness — String Matching & Edit Distance

These three problems (Edit Distance, Wildcard Matching, Regex Matching) fail candidates for the same reason every time: they don't nail the **state definition** before coding. Get the state right and the transitions almost write themselves.

### The universal 2-string DP template

For any "compare two strings" DP, define `dp[i][j]` as **the answer for the first `i` characters of `s` and the first `j` characters of `t`**. Build a `(len(s)+1) x (len(t)+1)` table so row/col 0 represent empty prefixes — this kills off-by-one bugs.

```python
def edit_distance(word1: str, word2: str) -> int:
    m, n = len(word1), len(word2)
    # dp[i][j] = min edits to convert word1[:i] -> word2[:j]
    dp = [[0] * (n + 1) for _ in range(m + 1)]

    # base cases: converting "" -> word2[:j] takes j inserts,
    # converting word1[:i] -> "" takes i deletes
    for i in range(m + 1):
        dp[i][0] = i
    for j in range(n + 1):
        dp[0][j] = j

    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if word1[i - 1] == word2[j - 1]:
                dp[i][j] = dp[i - 1][j - 1]  # chars match, no edit
            else:
                dp[i][j] = 1 + min(
                    dp[i - 1][j],      # delete from word1
                    dp[i][j - 1],      # insert into word1
                    dp[i - 1][j - 1],  # replace
                )
    return dp[m][n]
```

Wildcard Matching (`?` = any one char, `*` = any sequence including empty):

```python
def is_match_wildcard(s: str, p: str) -> bool:
    m, n = len(s), len(p)
    dp = [[False] * (n + 1) for _ in range(m + 1)]
    dp[0][0] = True

    # "" matches p[:j] only if p[:j] is all '*'
    for j in range(1, n + 1):
        if p[j - 1] == '*':
            dp[0][j] = dp[0][j - 1]

    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if p[j - 1] == '*':
                # '*' matches empty (dp[i][j-1]) or consumes one char of s (dp[i-1][j])
                dp[i][j] = dp[i][j - 1] or dp[i - 1][j]
            elif p[j - 1] == '?' or p[j - 1] == s[i - 1]:
                dp[i][j] = dp[i - 1][j - 1]
            # else: stays False
    return dp[m][n]
```

Regex Matching (`.` = any one char, `*` = zero or more of the **preceding** char — the trap that breaks most people):

```python
def is_match_regex(s: str, p: str) -> bool:
    m, n = len(s), len(p)
    dp = [[False] * (n + 1) for _ in range(m + 1)]
    dp[0][0] = True

    # "" matches p[:j] only if pairs are like "a*b*c*"
    for j in range(1, n + 1):
        if p[j - 1] == '*':
            dp[0][j] = dp[0][j - 2]

    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if p[j - 1] == '*':
                # zero occurrences of preceding char: skip the pair
                dp[i][j] = dp[i][j - 2]
                # one-or-more occurrences: preceding char matches s[i-1]
                prev = p[j - 2]
                if prev == '.' or prev == s[i - 1]:
                    dp[i][j] = dp[i][j] or dp[i - 1][j]
            elif p[j - 1] == '.' or p[j - 1] == s[i - 1]:
                dp[i][j] = dp[i - 1][j - 1]
    return dp[m][n]
```

### When to reach for this pattern

- Two sequences being compared, transformed, or aligned (edit distance, LCS, interleaving strings).
- The answer at position `(i, j)` only depends on `(i-1, j)`, `(i, j-1)`, `(i-1, j-1)` — a "look one step back in each string" relationship.
- `*`/`?` wildcard or regex-like matching against a pattern string.

### Space optimization

Every template above only reads the **previous row** of `dp`. Once it works, compress to two 1D arrays (or one array updated carefully right-to-left) — mention this proactively in interviews, it signals you understand the recurrence, not just the code.

```python
def edit_distance_optimized(word1: str, word2: str) -> int:
    m, n = len(word1), len(word2)
    prev = list(range(n + 1))
    for i in range(1, m + 1):
        curr = [i] + [0] * n
        for j in range(1, n + 1):
            if word1[i - 1] == word2[j - 1]:
                curr[j] = prev[j - 1]
            else:
                curr[j] = 1 + min(prev[j], curr[j - 1], prev[j - 1])
        prev = curr
    return prev[n]
```

**Verify you're actually strong here:** close this lesson and re-solve Edit Distance from a blank file in under 20 minutes, no notes. If you hesitate on the base case or the three-way `min`, you're not done — do Wildcard Matching next, cold, same rule.

## Block 2 (80 min): System Design Weakness

Pick your **three weakest designs** from everything you've drilled so far (Days 1-35). Don't pick three you're comfortable with — that's avoidance, not practice.

### Reusable building blocks (the vocabulary every design draws from)

| Block | Solves | Watch-out |
|---|---|---|
| Load balancer (L4/L7) | Distribute traffic, health checks | Sticky sessions break horizontal scaling |
| CDN | Static asset latency, edge caching | Cache invalidation on deploy |
| Cache (Redis) | Read latency, DB offload | Stampede on expiry, staleness |
| Message queue (Kafka/SQS) | Decoupling, async work, backpressure | Ordering guarantees, at-least-once delivery |
| DB read replicas | Read scaling | Replication lag = stale reads |
| Sharding | Write scaling, dataset size | Cross-shard queries/joins get expensive |
| Rate limiter | Abuse protection, fairness | Token bucket vs. sliding window tradeoffs |
| Consistent hashing | Even distribution across nodes that change | Hot keys still need special handling |
| Object storage (S3-like) | Large blobs, media | Not a substitute for a real DB index |

### Redesign-from-scratch checklist

Run every one of your three weak designs through this in order, out loud, against a timer:

1. **Requirements** — functional (3-5 core features) and non-functional (scale numbers: DAU, QPS, read:write ratio, latency target).
2. **Capacity estimate** — back-of-envelope storage/bandwidth from the numbers in step 1. Say the math out loud.
3. **API design** — 3-5 endpoints, request/response shape.
4. **High-level architecture** — draw the boxes (client, LB, service, cache, DB, queue) and the data flow through them.
5. **Deep dive** — pick the ONE hardest part of this system (e.g., feed ranking, message ordering, deduplication) and go deep.
6. **Bottlenecks & tradeoffs** — where does this break at 10x scale? What did you trade away (consistency, cost, complexity)?

Compare each redesign against a reference solution afterward. Don't just read the reference — write down the **specific gap**: did you miss a bottleneck, skip capacity estimation, or under-specify the data model? That gap is the thing to drill again before Day 45.

**Verify you're actually strong here:** explain one of the three, start to finish, out loud, in under 10 minutes with no pauses longer than 3 seconds. If you get stuck at the deep-dive step, that's your actual weak point — not the system as a whole.

## Block 3 (80 min): Frontend Weakness

Frontend weaknesses are almost always one of these four. Build a tiny example for whichever ones you're shaky on — reading docs without writing code doesn't fix interview performance.

### useEffect dependency arrays

```tsx
// WRONG: missing dependency, stale closure over `userId`
useEffect(() => {
  fetchUser(userId).then(setUser);
}, []); // eslint would flag this

// RIGHT: effect re-runs whenever userId changes, no stale data
useEffect(() => {
  let cancelled = false;
  fetchUser(userId).then((u) => { if (!cancelled) setUser(u); });
  return () => { cancelled = true; }; // cleanup avoids setting state after unmount
}, [userId]);
```

Say out loud: "the dependency array is not an optimization, it's correctness — it tells React when the closure's captured values are stale."

### useMemo / useCallback — when they matter and when they don't

```tsx
// Only memoize when the computation is expensive OR the identity
// is passed to a memoized child / effect dependency.
const sorted = useMemo(() => expensiveSort(items), [items]);

const handleClick = useCallback(() => {
  onSelect(item.id);
}, [item.id, onSelect]);
```

The common wrong answer: "I memoize everything for performance." The right answer: "memoization has its own cost (comparing deps every render); I use it when the child is wrapped in `React.memo` and re-renders are measurably a problem, not by default."

### Reconciliation and keys

```tsx
// WRONG: index as key when list order can change — causes state to
// attach to the wrong item after reorder/delete
{items.map((item, i) => <Row key={i} {...item} />)}

// RIGHT: stable, unique id
{items.map((item) => <Row key={item.id} {...item} />)}
```

Be able to explain: React diffs siblings by key; a stable key lets React match DOM nodes (and their internal state) across renders instead of recreating them.

### Controlled vs. uncontrolled components

```tsx
// Controlled: React state is the single source of truth
function ControlledInput() {
  const [value, setValue] = useState("");
  return <input value={value} onChange={(e) => setValue(e.target.value)} />;
}

// Uncontrolled: DOM holds the value, read via ref when needed
function UncontrolledInput() {
  const ref = useRef<HTMLInputElement>(null);
  const submit = () => console.log(ref.current?.value);
  return <input ref={ref} defaultValue="" />;
}
```

Know the tradeoff: controlled gives you validation-per-keystroke and predictable state but re-renders on every keystroke; uncontrolled is cheaper for large forms where you only need the value on submit.

**Verify you're actually strong here:** pick your weakest of the four topics above, then explain the "watch-out" in your own words out loud in under 60 seconds, no re-reading. If you can't, build the tiny example yourself (don't copy the snippet) before moving on.

## Key takeaways

- DP on two strings is one template — `dp[i][j]` over prefixes — reused for Edit Distance, Wildcard, and Regex matching; the only thing that changes is the transition logic.
- Regex Matching's `*` means "zero or more of the previous character," not "match anything" — that misunderstanding is the #1 cause of wrong solutions.
- System design weakness is rarely "I don't know the building blocks" — it's skipping capacity estimation or not going deep enough on the one hard part.
- Every system design should run through the same six-step checklist so nothing gets skipped under interview pressure.
- `useEffect` dependency arrays are a correctness tool, not a performance knob — treat missing dependencies as bugs.
- Verification beats review: re-solving cold and explaining out loud exposes gaps that re-reading a solution hides.
