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

[Reverse Integer (LeetCode 7)](https://leetcode.com/problems/reverse-integer/) asks you to reverse the digits of a 32-bit signed integer, returning `0` if the result overflows `[-2³¹, 2³¹ - 1]`. It's the same shape of problem as `Pow(x, n)`-style overflow questions elsewhere in this course: in both, the naive version works fine, and the interview is really about the overflow and edge-case handling.

## Approach 1: string conversion (works, but not the answer they want)

```python
def reverse(x: int) -> int:
    sign = -1 if x < 0 else 1
    rev = int(str(abs(x))[::-1]) * sign
    return rev if -(2**31) <= rev <= 2**31 - 1 else 0
```

Correct, but it relies on string allocation, and it only catches overflow *after the fact* because Python integers are unbounded. Most interviewers will push you toward the math approach next.

## Approach 2: digit extraction with an overflow check before it happens (the expected answer)

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

**Why check before, not after:** in a language with fixed-width integers (Java/C++), `result * 10 + digit` overflows *during* the computation. By the time you could check the result, it's already wrong: undefined behavior in C++, silent wraparound in Java. Checking `result > INT_MAX // 10` beforehand, since that condition means the next multiply would overflow, avoids ever computing the bad value.

**Why `digit > 7` specifically:** `2^31 - 1 = 2147483647`, and its last digit is `7`. If `result == INT_MAX // 10` exactly, the only digit that keeps the result in bounds is `≤ 7`; anything higher overflows.

**Complexity:** Time O(log₁₀ x), one iteration per digit. Space O(1).

## The portability point (worth naming explicitly)

Python integers are unbounded, so a Python-only solution could reverse first and clamp after (`rev = sign * int(str(abs(x))[::-1]); return rev if bounds else 0`) and it would still be "correct" for this problem. Say that out loud in the interview, though, along with the fact that it wouldn't hold up in Java or C++, where the multiply-add itself overflows before you get a chance to check anything. Approach 2's before-the-fact check is the one that translates directly to a fixed-width-integer language, and that's usually what the interviewer is actually testing.
