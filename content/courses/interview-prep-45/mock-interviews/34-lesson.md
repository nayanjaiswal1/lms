---
kind: lesson
id_key: interview-prep-45/day-34
course: interview-prep-45
section: mock-interviews
section_title: "Mock Interviews"
section_position: 7
title: "Mock Interviews 13–15: Trees, Airbnb, Frontend"
position: 34
estimated_minutes: 240
source:
    - 45-day-interview-roadmap.md
---

Three mocks today: a tree traversal problem solved two ways, a booking-system design where the interesting part is concurrency (not the box diagram), and a rapid-fire React theory round. Same rules as every mock day: hard timer, talk out loud, no reference material until your own attempt is done.

## Run of show

| Time | Segment |
|---|---|
| 0:00–0:30 | Mock 13: DSA, Binary Tree Level Order, BFS vs DFS (30 min) |
| 0:30–0:40 | Break: write down what went wrong while it's fresh |
| 0:40–1:20 | Mock 14: System Design, Design Airbnb (40 min) |
| 1:20–1:30 | Break |
| 1:30–2:00 | Mock 15: Frontend Deep, React theory Q&A (30 min) |
| 2:00–2:25 | Score against rubric, write debrief |
| 2:25–4:00 | Buffer: Validate BST, LCA, or Invert Binary Tree (pick one or two, cold) |

## Mock Interview 13: DSA, Binary Tree Level Order Traversal (30 minutes)

**Problem:** [Binary Tree Level Order Traversal (LeetCode 102)](https://leetcode.com/problems/binary-tree-level-order-traversal/). Given the root of a binary tree, return the level order traversal of its node values (i.e., from left to right, level by level), as a list of lists, one inner list per level.

```
Input: root = [3,9,20,null,null,15,7]
Output: [[3],[9,20],[15,7]]
```

**Instructions:** solve it with BFS first, then implement a DFS version that produces the same output, and be ready to explain when you'd reach for each.

**Clarifying hints an interviewer would give if you don't ask:**
- "Empty tree?" Return `[]`.
- "Does node value range matter (negatives, duplicates)?" No constraint, don't assume positive/unique.
- "Left-to-right order within a level, confirmed?" Yes, that's the definition; say it back before coding.

Budget: 2 min clarify, 5 min discuss BFS vs DFS approach, 15 min code both, 8 min test and compare.

### Reference solution

```python
from collections import deque
from typing import Optional


class TreeNode:
    def __init__(self, val=0, left=None, right=None):
        self.val = val
        self.left = left
        self.right = right


def level_order_bfs(root: Optional[TreeNode]) -> list[list[int]]:
    """Queue-based BFS. The 'snapshot the queue length before draining it'
    trick is what separates levels without needing a sentinel value."""
    if not root:
        return []
    result: list[list[int]] = []
    queue = deque([root])
    while queue:
        level_size = len(queue)
        level = []
        for _ in range(level_size):
            node = queue.popleft()
            level.append(node.val)
            if node.left:
                queue.append(node.left)
            if node.right:
                queue.append(node.right)
        result.append(level)
    return result


def level_order_dfs(root: Optional[TreeNode]) -> list[list[int]]:
    """Pre-order DFS carrying a depth counter. Appends a new level list the
    first time a given depth is reached, then appends into it on every
    subsequent visit at that depth."""
    result: list[list[int]] = []

    def dfs(node: Optional[TreeNode], depth: int) -> None:
        if not node:
            return
        if depth == len(result):
            result.append([])
        result[depth].append(node.val)
        dfs(node.left, depth + 1)
        dfs(node.right, depth + 1)

    dfs(root, 0)
    return result


def build_sample() -> TreeNode:
    return TreeNode(3, TreeNode(9), TreeNode(20, TreeNode(15), TreeNode(7)))


if __name__ == "__main__":
    root = build_sample()
    assert level_order_bfs(root) == [[3], [9, 20], [15, 7]]
    assert level_order_dfs(root) == [[3], [9, 20], [15, 7]]
    assert level_order_bfs(None) == []
    assert level_order_dfs(None) == []
    assert level_order_bfs(TreeNode(1)) == [[1]]
    print("ok")
```

**What to explain out loud, comparing the two:** BFS is the natural fit. A queue processes nodes in the exact order levels are defined, and the "capture `len(queue)` before draining" trick is the one piece of mechanics worth having cold, since without it you can't tell where one level ends and the next begins. Both are O(n) time and O(n) space (BFS: queue holds up to the width of the tree, up to n/2 nodes at the last level of a complete tree; DFS: recursion stack holds up to the height h, but the output list itself is O(n) either way, and pre-order visits every node once). DFS is less intuitive for this specific problem, since it's not naturally level-by-level, but it's worth showing because it demonstrates you can adapt a traversal you already have running (say, for another purpose) to also produce level order, without introducing a second data structure. State the trade-off plainly: BFS is the default reasonable choice here; DFS shows range and is preferable in practice only if you're already deep in a DFS-based traversal elsewhere in the same codebase and don't want a second pass.

**Extra practice for the buffer block:** three more tree problems that reuse today's traversal muscle.
- **Validate BST:** DFS with a running `(low, high)` bound passed down to each recursive call, tightened at every step (don't just check `node.left.val < node.val < node.right.val`, that misses violations from a grandparent two levels up).
- **Lowest Common Ancestor (LCA):** for a general binary tree, DFS returns the node itself when found, `null` otherwise, and the current node when both children return non-null (that's the split point). For a BST specifically, exploit ordering: no full traversal needed, O(h) using comparisons alone.
- **Invert Binary Tree:** swap `left`/`right` at every node, recursively (or iteratively with a queue/stack). O(n) time, O(h) or O(n) space depending on recursive vs iterative.

## Mock Interview 14: System Design, Design Airbnb (40 minutes)

**Prompt as the interviewer would give it:** "Design a system like Airbnb. Hosts list properties, guests search and book them for date ranges. Focus on the booking flow, especially preventing double-booking."

Time budget: 5 min requirements, 10 min high-level architecture, 18 min deep dive on booking concurrency (this is the part that matters), 7 min scaling and trade-offs.

**Clarifying questions to ask out loud:**
- Instant book, or does the host approve each request?
- Is payment part of the design, or assume an external processor?
- Search: filter by location/dates/price only, or also amenities/ratings?
- Scale: how many listings, how many concurrent booking attempts on a popular listing?

### Reference solution

**Functional requirements:** search listings by location/date range/price, view a listing, book a listing for a date range, host manages listing availability, payment is captured on booking.
**Non-functional requirements:** search can be eventually consistent and needs to scale for read-heavy traffic; **booking must be strongly consistent: two guests can never be confirmed for overlapping dates on the same listing.** That last point is the crux of the entire design; say it early and let it drive the deep dive.

**High-level architecture:**
```
Client -> API Gateway -> Search service (Elasticsearch: geo + date + price query, eventually consistent)
                       -> Listing service (Postgres: listing details, photos, amenities)
                       -> Booking service (Postgres: bookings + availability, strongly consistent)
                       -> Payment service (external gateway, idempotent charge)
                       -> Notification service (email/push confirmation)
```

Search is intentionally split from booking: search tolerates staleness (a listing that just got booked might still show as available for a few seconds in results, which is acceptable since it gets caught at booking time), booking does not.

**The double-booking problem: this is the deep dive.**

Naive flow: `check availability for (listing_id, date_range)` → if free, `insert booking`. Two concurrent requests for the same overlapping range can both pass the check before either insert commits: a classic time-of-check-to-time-of-use race. Walk through three fixes and pick one with reasoning, don't just present one as if there were no alternative:

1. **Database exclusion constraint (the clean fix).** Postgres supports `EXCLUDE USING gist`, which lets the database itself atomically reject an overlapping insert. No application-level locking or retry logic needed:
```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE bookings (
    id BIGSERIAL PRIMARY KEY,
    listing_id BIGINT NOT NULL,
    guest_id BIGINT NOT NULL,
    date_range DATERANGE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    EXCLUDE USING gist (listing_id WITH =, date_range WITH &&)
);
```
   Any insert whose `date_range` overlaps an existing row for the same `listing_id` fails at the database layer with a constraint violation, which the app catches and returns as "dates no longer available." Correctness is enforced by the database regardless of application bugs, race conditions, or a second service instance nobody remembered about.

2. **Pessimistic locking.** `BEGIN; SELECT ... FROM listings WHERE id = ? FOR UPDATE; -- check availability -- INSERT booking; COMMIT;` locks the listing row for the duration of the transaction, serializing all booking attempts for that one listing. Simple to reason about, and fine because contention is per-listing, not global: a single popular listing being booked by many people simultaneously is rare and the lock hold time is short.

3. **Optimistic concurrency.** Version/timestamp column on availability, write fails if the version changed since read, client retries. More complex for no real benefit here since booking isn't a high-contention hot loop the way, say, a shared counter is.

**Recommendation to state explicitly:** the exclusion constraint is the strongest choice. It's declarative, enforced at the data layer, and survives future bugs in application code that a lock-based approach wouldn't (someone forgets the `FOR UPDATE` in a new code path, and the guard is silently gone). Say this, then mention pessimistic locking as the fallback if the database doesn't support exclusion constraints (e.g. a NoSQL store), which is a fair follow-up an interviewer might push on.

**Payment and booking coordination:** don't charge the card before the booking is confirmed available, and don't confirm the booking before the charge succeeds. Use a short-lived "pending" booking state: insert the pending booking (which is what actually reserves the dates via the exclusion constraint), attempt payment, then transition to "confirmed" on success or delete/roll back on payment failure. Use an idempotency key per booking attempt so a client retry (double-click, network blip) can't double-charge.

**Data model (booking service):**
```sql
CREATE TABLE listings (
    id BIGSERIAL PRIMARY KEY,
    host_id BIGINT NOT NULL,
    title TEXT NOT NULL,
    location POINT,
    price_cents INT NOT NULL
);
```
(bookings table shown above already covers the availability-critical piece.)

**Scaling and trade-offs:**
- Search is the read-heavy path: Elasticsearch/geo index, cached listing detail pages (images/description change rarely), and it can lag booking state by seconds without correctness issues.
- Booking is low-volume relative to search/browse (a user searches many times per one booking), so it doesn't need to scale the same way. Don't over-design sharding for a service whose real bottleneck is correctness, not throughput.
- If a specific listing goes viral and gets hammered with simultaneous booking attempts, the exclusion constraint or row lock naturally serializes them. No extra work needed: the correctness mechanism doubles as the concurrency control.

**Failure modes to name:** payment succeeds but the "confirm booking" write fails (needs a reconciliation job or the idempotency key to make retry safe), and a host importing an external calendar (iCal sync from another platform) can create a race between two independent booking sources. Call this out as a real eventual-consistency risk that the exclusion constraint alone doesn't fully solve if the external calendar isn't synced through the same transaction.

## Mock Interview 15: Frontend Deep, React Theory (30 minutes)

**Instructions:** set a 30-minute timer. Rapid Q&A, not a coding round. Answer each question out loud in 5–8 minutes as if explaining to a teammate who half-knows React, then compare against the reference answer.

**Question 1: How does reconciliation work?**

*Reference answer:* Reconciliation is how React decides what actually needs to change in the DOM when state updates. It diffs the new element tree against the previous one using a few key heuristics rather than a full generic tree-diff (which would be too slow): if the element type at a given position changes (`<div>` → `<span>`), React tears down that entire subtree and rebuilds it from scratch, with no attempt to diff children across the type change. If the type is the same, React keeps the underlying DOM node and only patches changed attributes, then recurses into children. For lists, the `key` prop tells React how to match children across renders; without stable keys, React falls back to positional matching, which breaks badly on reorder/insert (state gets attached to the wrong item, unnecessary unmount/remounts happen). Since React 16, this runs on the Fiber architecture: reconciliation work is broken into units that can be paused, resumed, or abandoned by priority, which is what makes concurrent features like `startTransition` possible. If pushed, give a concrete example: reordering a list keyed by array index versus keyed by a stable ID, and what breaks in the index case (an input's local state or focus jumping to the wrong row).

The index-key bug, made concrete. Have this ready if the interviewer asks "show me":

```tsx
// Buggy: index as key. Deleting the first todo makes every remaining
// row's key shift by one, so React matches stale DOM (and any local
// state like an uncontrolled input's cursor position) to the wrong item.
{todos.map((todo, index) => (
  <TodoRow key={index} todo={todo} />
))}

// Correct: stable identity that survives reordering/deletion.
{todos.map((todo) => (
  <TodoRow key={todo.id} todo={todo} />
))}
```

**Question 2: When would you use `useMemo`?**

*Reference answer:* `useMemo` caches the result of an expensive computation between renders, recomputing only when a listed dependency changes. Two legitimate uses: (1) a genuinely heavy synchronous computation, such as filtering/sorting/transforming a large array, that would otherwise re-run on every render even when its inputs are unchanged; (2) preserving referential equality of an object or array passed as a prop to a `React.memo`-wrapped child, or used as a dependency in another hook. Without it, a new object literal is created every render, which breaks `React.memo`'s shallow-equality check and silently defeats the optimization it was supposed to provide. The trap to name explicitly: wrapping cheap computations in `useMemo` "just in case." The memoization itself costs a dependency comparison and a cache slot every render, and for something like `a + b` that overhead has no computation to offset it. The rule to state: profile first, memoize the measured hot path, not everything reflexively.

**Question 3: Explain the component lifecycle.**

*Reference answer:* In class components, three phases: mounting (`constructor` → `render` → `componentDidMount`), updating (`render` → `componentDidUpdate`, gated optionally by `shouldComponentUpdate` or `getDerivedStateFromProps`), unmounting (`componentWillUnmount` for cleanup: removing listeners, cancelling subscriptions/timers). Function components map the same three phases onto `useEffect`: the effect body runs after render commits (on mount, and again on every update where a listed dependency changed), and the function it returns is the cleanup, which runs before the next effect invocation and on unmount. The dependency array controls which phase you're in: `[]` means mount-once/unmount-once, no array means every render, `[x]` means mount plus whenever `x` changes. Name the common trap explicitly: forgetting the cleanup function in `useEffect`. Event listeners, subscriptions, and interval timers that never get torn down cause leaks that were harder to accidentally skip in class components, since `componentWillUnmount` was its own separate, impossible-to-forget-you-have-one method.

## Scoring rubric

**Mock 13: DSA (Binary Tree Level Order)**
- BFS solution correct and used the level-size-snapshot technique cleanly: 5 = wrote it without hesitation; 1 = needed a hint to separate levels at all.
- DFS solution correct and produced identical output: 5 = implemented depth-indexed appending correctly on the first try; 1 = couldn't adapt DFS to produce level grouping.
- Explained complexity and the real trade-off between the two (not just "both are O(n)"): 5 = articulated when DFS would actually be preferable in practice; 1 = no comparison offered unprompted.
- Handled edge cases (empty tree, single node, unbalanced tree): 5 = tested all three; 1 = only tested the balanced sample tree.

**Mock 14: System Design (Airbnb)**
- Identified the double-booking race condition as the central design problem: 5 = named it unprompted in the first ten minutes; 1 = designed the whole system without ever mentioning concurrent booking risk.
- Proposed a concrete, correct fix (exclusion constraint, row lock, or optimistic concurrency) with reasoning for the choice: 5 = named multiple options and picked one with a stated trade-off; 1 = proposed a fix that doesn't actually prevent the race (e.g. "check then insert" with no locking).
- Separated search (eventually consistent) from booking (strongly consistent) explicitly: 5 = stated this distinction and why each side tolerates different consistency; 1 = treated the whole system as needing uniform consistency.
- Handled payment/booking coordination correctly (pending state, idempotency): 5 = designed a flow where a failed payment can't leave a confirmed-but-unpaid booking; 1 = charged the card before confirming availability, or didn't address the coordination at all.

**Mock 15: Frontend Deep (React Theory)**
- Reconciliation answer covered type-change teardown, key-based list matching, and Fiber's interruptibility: 5 = covered all three with a concrete example; 1 = vague "React updates the DOM efficiently" with no mechanism.
- `useMemo` answer named both legitimate use cases and the overuse trap: 5 = gave the referential-equality use case unprompted, not just "expensive computations"; 1 = couldn't explain when it's *not* worth using.
- Lifecycle answer correctly mapped class lifecycle methods to hook equivalents: 5 = mapped all three phases and named the cleanup-forgetting trap; 1 = could describe class lifecycle but not the hooks equivalent, or vice versa.

## Debrief

Log mistakes right after each mock while they're fresh. For Mock 13, note whether BFS vs DFS was actually a choice you reasoned through or just "the one I happened to remember." Pattern recognition speed on tree traversal type (BFS for level/shortest-path-shaped problems, DFS for path-sum/subtree-shaped problems) is the transferable skill, not the specific code. For Mock 14, note precisely how fast you spotted the double-booking race: if it took a hint, that's a signal to drill "what breaks under concurrency" as a standing question for every future system design mock, not just booking systems. For Mock 15, flag any answer that was accurate but shallow (correct terminology, no concrete example). That's exactly the gap a strong interviewer's follow-up question exposes, so rewrite that answer with a specific example before it goes stale. Everything scored 3/5 or below goes on tomorrow's warm-up.
