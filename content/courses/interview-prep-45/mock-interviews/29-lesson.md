---
kind: lesson
id_key: interview-prep-45/day-29
course: interview-prep-45
section: mock-interviews
section_title: "Mock Interviews"
section_position: 7
title: "Day 29 — Mock Interview - Arrays and Strings"
position: 29
estimated_minutes: 240
source:
    - 45-day-interview-roadmap.md
---

Run this alone, like the real thing. Start a timer for each segment and do not pause it, talk out loud the entire time even though no one is listening, and do not open the reference solution until you've submitted your own answer or the clock runs out. If you get stuck, say what you'd ask an interviewer instead of guessing silently — that's the skill being graded.

## Run of show

| Time | Segment |
|---|---|
| 0:00–0:35 | Coding: Two Sum (15 min) + Longest Substring Without Repeating (20 min) |
| 0:35–0:45 | Break — write down what went wrong while it's fresh |
| 0:45–1:25 | System Design: URL Shortener (40 min) |
| 1:25–1:35 | Break |
| 1:35–2:05 | Frontend: build an Autocomplete Search component (30 min) |
| 2:05–2:30 | Score yourself against the rubric below, write debrief notes |
| 2:30–4:00 | Buffer — redo the segment you scored weakest on, from scratch, no notes |

## Segment 1: Coding — Arrays and Strings

### Problem 1: Two Sum (15 minutes)

Given an array of integers `nums` and an integer `target`, return the indices of the two numbers that add up to `target`. Assume exactly one solution exists, and you may not use the same element twice.

```
Input: nums = [2, 7, 11, 15], target = 9
Output: [0, 1]   # nums[0] + nums[1] == 9
```

**Clarifying hints an interviewer would give if you don't ask:**
- "Can the array be unsorted?" — Yes, don't assume order.
- "Are there duplicate values?" — Yes, handle `[3, 3]` with `target = 6`.
- "Return indices or values?" — Indices, in any order.
- "What if no solution exists?" — Out of scope here; assume guaranteed exactly one, but say out loud what you'd do (raise/return empty) if asked.

Budget: 2 min clarify, 3 min brute-force-then-optimize discussion, 7 min code, 3 min test out loud.

#### Reference solution

```python
def two_sum(nums: list[int], target: int) -> list[int]:
    seen: dict[int, int] = {}  # value -> index
    for i, n in enumerate(nums):
        complement = target - n
        if complement in seen:
            return [seen[complement], i]
        seen[n] = i
    raise ValueError("no two sum solution")


if __name__ == "__main__":
    assert two_sum([2, 7, 11, 15], 9) == [0, 1]
    assert two_sum([3, 3], 6) == [0, 1]
    assert sorted(two_sum([3, 2, 4], 6)) == [1, 2]
    print("ok")
```

Time: O(n), one pass. Space: O(n) for the hash map. Brute force is O(n^2)/O(1) — mention it, then justify the trade-up to hashing since interviews reward the reasoning, not just the answer.

### Problem 2: Longest Substring Without Repeating Characters (20 minutes)

Given a string `s`, find the length of the longest substring without repeating characters.

```
Input: s = "abcabcbb"
Output: 3   # "abc"
Input: s = "bbbbb"
Output: 1   # "b"
Input: s = "pwwkew"
Output: 3   # "wke"
```

**Clarifying hints:**
- "What character set?" — Assume ASCII/Unicode, don't assume lowercase-only.
- "Empty string?" — Return 0.
- "Substring vs subsequence?" — Substring: must be contiguous.

Budget: 2 min clarify, 5 min approach (naive O(n^3) then sliding window), 10 min code, 3 min test.

#### Reference solution

```python
def length_of_longest_substring(s: str) -> int:
    last_seen: dict[str, int] = {}
    start = 0
    best = 0
    for i, ch in enumerate(s):
        if ch in last_seen and last_seen[ch] >= start:
            start = last_seen[ch] + 1
        last_seen[ch] = i
        best = max(best, i - start + 1)
    return best


if __name__ == "__main__":
    assert length_of_longest_substring("abcabcbb") == 3
    assert length_of_longest_substring("bbbbb") == 1
    assert length_of_longest_substring("pwwkew") == 3
    assert length_of_longest_substring("") == 0
    print("ok")
```

Time: O(n) — sliding window, each index enters/exits the window once. Space: O(min(n, charset size)) for the map. Naive substring-by-substring check is O(n^3); mention it and explain why the window collapses it.

## Segment 2: System Design — URL Shortener (40 minutes)

**Prompt as the interviewer would give it:** "Design a service like bit.ly. Users submit a long URL and get back a short one; visiting the short URL redirects to the original."

Time budget: 5 min requirements, 10 min high-level architecture, 15 min deep dive, 10 min scaling/trade-offs.

**Clarifying questions to ask out loud (an interviewer expects these unprompted):**
- Custom aliases, or system-generated only?
- Expected read:write ratio? (Typically read-heavy, 100:1 or more.)
- Do short URLs expire?
- Do we need click analytics?
- Scale target — QPS, total URLs stored?

### Reference solution

**Functional requirements:** create short URL from long URL, redirect short → long, optional custom alias, optional expiration.
**Non-functional requirements:** low redirect latency (<100ms), high availability for redirects, uniqueness of short codes, eventual consistency acceptable for analytics.

**Capacity estimate:** 100M new URLs/month ≈ 40 writes/sec average. Read:write of 100:1 ≈ 4,000 reads/sec average, spike to 10x at peak. Each record ~500 bytes → 100M × 500B = 50GB/month, a few TB over years — fits a normal relational store with an index, no exotic storage needed.

**High-level architecture:**
```
Client -> API Gateway/LB -> App servers (stateless) -> Cache (Redis) -> DB (Postgres, primary + read replicas)
                                                     -> Async analytics pipeline (Kafka -> aggregator)
```

**Encoding short codes:** take an auto-increment ID from the DB (or a distributed ID generator like Snowflake if multiple writers), base62-encode it (`[a-zA-Z0-9]`, 62 symbols). 7 characters of base62 gives 62^7 ≈ 3.5 trillion codes — more than enough. Base62 over random-string-and-check-collision avoids retry loops under contention.

```python
ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

def encode_base62(num: int) -> str:
    if num == 0:
        return ALPHABET[0]
    digits = []
    base = len(ALPHABET)
    while num:
        num, rem = divmod(num, base)
        digits.append(ALPHABET[rem])
    return "".join(reversed(digits))
```

**Data model:**
```sql
CREATE TABLE urls (
    id BIGSERIAL PRIMARY KEY,
    short_code VARCHAR(10) UNIQUE NOT NULL,
    long_url TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    expires_at TIMESTAMPTZ,
    owner_id BIGINT
);
CREATE INDEX idx_urls_short_code ON urls(short_code);
```

**Write path:** client POSTs long URL → app server inserts row, gets auto-increment ID → base62-encode → update row with short_code (or reserve ID ranges per app server to avoid a second write). Return short URL.

**Read path (the hot path):** GET `/{code}` → check Redis cache for `code -> long_url` → cache hit: 301/302 redirect immediately → cache miss: query Postgres, populate cache with TTL, redirect. Use 302 (not 301) if you want every hit to hit your server for analytics; 301 lets browsers cache it and reduces your load but loses click data — this is the trade-off to state explicitly.

**Scaling:**
- Read replicas + cache absorb the 100:1 read skew; cache hit rate should be >95% given Zipfian popularity of URLs.
- Shard the DB by `short_code` hash once a single Postgres instance can't hold the write/index volume — but at 40 writes/sec this is a "not yet" and you should say so rather than over-designing.
- CDN edge caching for extremely hot redirects if latency to origin matters globally.
- Async pipeline (Kafka → aggregator → analytics DB) for click counts so the redirect path never blocks on write-heavy analytics.

**Failure modes to mention:** cache stampede on a cold cache after deploy (mitigate with request coalescing or pre-warming), ID generator becoming a single point of failure (mitigate with Snowflake-style distributed IDs or reserved ID blocks per server), duplicate long URLs (decide: dedupe with a reverse index, or allow duplicates — state the trade-off, don't just pick one silently).

## Segment 3: Frontend — Autocomplete Search Component (30 minutes)

**Prompt:** "Build a search input that fetches suggestions as the user types, shows a dropdown, and lets them select a result with mouse or keyboard."

Time budget: 5 min plan component structure/state, 20 min implement, 5 min discuss performance/accessibility.

**Clarifying hints:**
- "Debounce or throttle the API calls?" — Debounce; you don't want a request per keystroke.
- "What happens on slow network / stale response arriving late?" — Must guard against out-of-order responses overwriting fresher ones.
- "Keyboard navigation required?" — Yes: arrow keys, Enter to select, Escape to close.
- "Accessibility?" — ARIA combobox pattern, screen-reader announcements.

### Reference solution

```tsx
import { useState, useEffect, useMemo, useRef, useCallback } from "react";

interface Suggestion {
  id: string;
  label: string;
}

async function fetchSuggestions(query: string, signal: AbortSignal): Promise<Suggestion[]> {
  const res = await fetch(`/api/search?q=${encodeURIComponent(query)}`, { signal });
  if (!res.ok) throw new Error(`search failed: ${res.status}`);
  return res.json();
}

function useDebouncedValue<T>(value: T, delayMs: number): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delayMs);
    return () => clearTimeout(timer);
  }, [value, delayMs]);
  return debounced;
}

export function AutocompleteSearch({ onSelect }: { onSelect: (s: Suggestion) => void }) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<Suggestion[]>([]);
  const [activeIndex, setActiveIndex] = useState(-1);
  const [isOpen, setIsOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const debouncedQuery = useDebouncedValue(query, 250);
  const abortRef = useRef<AbortController | null>(null);

  useEffect(() => {
    if (!debouncedQuery.trim()) {
      setResults([]);
      setIsOpen(false);
      return;
    }
    abortRef.current?.abort();
    const controller = new AbortController();
    abortRef.current = controller;
    setLoading(true);
    fetchSuggestions(debouncedQuery, controller.signal)
      .then((data) => {
        setResults(data);
        setIsOpen(true);
        setActiveIndex(-1);
      })
      .catch((err) => {
        if (err.name !== "AbortError") console.error(err);
      })
      .finally(() => setLoading(false));
    return () => controller.abort();
  }, [debouncedQuery]);

  const listId = "autocomplete-listbox";

  const handleSelect = useCallback(
    (item: Suggestion) => {
      onSelect(item);
      setQuery(item.label);
      setIsOpen(false);
      setActiveIndex(-1);
    },
    [onSelect]
  );

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (!isOpen || results.length === 0) return;
    if (e.key === "ArrowDown") {
      e.preventDefault();
      setActiveIndex((i) => Math.min(i + 1, results.length - 1));
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setActiveIndex((i) => Math.max(i - 1, 0));
    } else if (e.key === "Enter" && activeIndex >= 0) {
      e.preventDefault();
      handleSelect(results[activeIndex]);
    } else if (e.key === "Escape") {
      setIsOpen(false);
    }
  };

  const visibleResults = useMemo(() => results.slice(0, 10), [results]);

  return (
    <div role="combobox" aria-expanded={isOpen} aria-owns={listId} aria-haspopup="listbox">
      <input
        type="text"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        onKeyDown={handleKeyDown}
        aria-autocomplete="list"
        aria-controls={listId}
        aria-activedescendant={activeIndex >= 0 ? `opt-${activeIndex}` : undefined}
        placeholder="Search..."
      />
      {loading && <span aria-live="polite">Loading…</span>}
      {isOpen && (
        <ul id={listId} role="listbox">
          {visibleResults.map((item, i) => (
            <li
              key={item.id}
              id={`opt-${i}`}
              role="option"
              aria-selected={i === activeIndex}
              onMouseDown={() => handleSelect(item)}
              style={{ background: i === activeIndex ? "#eee" : undefined }}
            >
              {item.label}
            </li>
          ))}
          {visibleResults.length === 0 && <li>No results</li>}
        </ul>
      )}
    </div>
  );
}
```

**Why these choices:** debounce (not throttle) because we only care about the final pause in typing, not steady-state rate. `AbortController` cancels in-flight requests so a slow earlier response can't overwrite a faster later one (the out-of-order bug interviewers specifically probe for). `useMemo` caps the render list at 10 items so a huge result set doesn't blow up the DOM. `onMouseDown` instead of `onClick` on options avoids the input's `onBlur` firing before the click registers. ARIA combobox roles make it usable with a screen reader, not just visually.

## Scoring rubric

Score each /5. Be honest — this only works if you grade like an interviewer, not like your own cheerleader.

**Coding (Two Sum + Longest Substring)**
- Clarified the problem before coding (asked about duplicates, edge cases, input assumptions): 5 = asked unprompted before writing a line; 1 = started coding immediately, clarified nothing.
- Considered edge cases (empty input, no solution, single character): 5 = enumerated them out loud and tested at least one; 1 = only tested the happy path.
- Discussed time/space complexity: 5 = stated Big-O for both brute force and optimized, explained the trade-off; 1 = never mentioned complexity unless asked.
- Code cleanliness: 5 = meaningful names, no dead code, would pass code review as-is; 1 = single-letter variables everywhere, needs a rewrite.

**System Design (URL Shortener)**
- Asked clarifying questions: 5 = drove requirements gathering before designing; 1 = jumped straight to drawing boxes.
- Covered functional and non-functional requirements: 5 = explicitly separated the two and used non-functional reqs to justify design choices; 1 = only listed features, no mention of scale/latency/availability.
- Discussed trade-offs: 5 = named at least two real trade-offs (e.g. 301 vs 302, SQL vs NoSQL, cache TTL) with a reasoned pick; 1 = presented one design with no alternatives considered.
- Handled follow-ups: 5 = answered "what if this server dies" / "what if traffic 10x's" confidently with a concrete change; 1 = froze or repeated the original design unchanged.

**Frontend (Autocomplete)**
- Planned component structure before coding: 5 = sketched state variables and data flow first; 1 = started typing JSX with no plan.
- Handled edge cases (empty query, race conditions, no results): 5 = explicitly handled abort/race conditions; 1 = didn't consider stale responses at all.
- Considered accessibility: 5 = used correct ARIA roles and keyboard support unprompted; 1 = mouse-only, no ARIA attributes.

## Debrief

Immediately after each segment — not at the end of the day, while it's fresh — write down every place you hesitated, guessed, or needed the reference solution. For each one, record: what the mistake was, what the root cause was (knowledge gap vs. nerves vs. time pressure), and the specific fix (a problem to redo, a concept to re-read, a pattern to drill). Add anything scored 3/5 or below into tomorrow's warm-up so it gets revisited within 48 hours — that's the window where spaced repetition actually sticks.

## Today's checklist

- [ ] Two Sum — solved in 15 minutes
- [ ] Longest Substring Without Repeating — solved in 20 minutes
- [ ] Practiced thinking out loud on both problems
- [ ] URL Shortener: defined requirements in 5 minutes
- [ ] URL Shortener: high-level architecture in 10 minutes
- [ ] URL Shortener: deep dive in 15 minutes
- [ ] URL Shortener: scaling discussion in 10 minutes
- [ ] Built the Autocomplete component from scratch
- [ ] Added state management (query, results, active index, loading)
- [ ] Optimized for performance (debounce, abort stale requests, memoized list)
- [ ] Scored every segment against the rubric and logged debrief notes
