---
kind: lesson
id_key: interview-prep-45/note-reverse-integer
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Notes: Reverse Integer"
position: 97
estimated_minutes: 10
source:
    - interview-prep-notes.md
---

[Reverse Integer (LeetCode 7)](https://leetcode.com/problems/reverse-integer/) — reverse the digits of a 32-bit signed integer, returning `0` if the result overflows `[-2³¹, 2³¹ - 1]`. A good pairing with Day 25's `Pow(x, n)` — both are "the naive version works, the interview is about the overflow/edge-case handling."

## Approach 1 — string conversion (works, but not the answer they want)

```python
def reverse(x: int) -> int:
    sign = -1 if x < 0 else 1
    rev = int(str(abs(x))[::-1]) * sign
    return rev if -(2**31) <= rev <= 2**31 - 1 else 0
```

Correct, but relies on string allocation and Python's unbounded integers doing the overflow check *after the fact* — most interviewers push you toward the math approach next.

## Approach 2 — digit extraction with overflow check before it happens (the expected answer)

```python
def reverse(x: int) -> int:
    INT_MIN, INT_MAX = -(2**31), 2**31 - 1
    result = 0
    sign = -1 if x < 0 else 1
    x = abs(x)

    while x != 0:
        digit = x % 10
        x //= 10

        # check BEFORE updating result — after would already have overflowed
        if result > INT_MAX // 10 or (result == INT_MAX // 10 and digit > 7):
            return 0

        result = result * 10 + digit

    return sign * result
```

**Why check before, not after:** in a language with fixed-width integers (Java/C++), `result * 10 + digit` overflows *during* the computation — by the time you could check the result, it's already wrong (undefined behavior in C++, wraps in Java). Checking `result > INT_MAX // 10` (would overflow on the next multiply) beforehand avoids ever computing the overflowed value.

**Why `digit > 7` specifically:** `2^31 - 1 = 2147483647` — its last digit is `7`. If `result == INT_MAX // 10` exactly, the only digit that keeps the result in bounds is `≤ 7`; anything higher overflows.

**Complexity:** Time O(log₁₀ x) — one iteration per digit. Space O(1).

## The portability point (worth naming explicitly)

Python integers are unbounded, so a Python-only solution could reverse first and clamp after (`rev = sign * int(str(abs(x))[::-1]); return rev if bounds else 0`) and it would still be "correct" for this problem — but say out loud that this wouldn't compile the same way in Java/C++, where the multiply-add itself overflows before you get a chance to check anything. Approach 2's before-the-fact check is the one that translates directly to a fixed-width-integer language, which is usually what the interviewer is actually testing.

## Key takeaways

- Check for overflow *before* the operation that would cause it (`result > INT_MAX // 10`), not after — the after-the-fact check only works because Python integers don't actually overflow.
- The `digit > 7` boundary comes directly from `INT_MAX`'s last digit (`2147483647`).
- Naming the string-vs-math tradeoff, and why the math version is the one that generalizes to fixed-width-integer languages, is the signal interviewers are listening for.
