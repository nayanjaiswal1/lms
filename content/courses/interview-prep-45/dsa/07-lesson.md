---
kind: lesson
id_key: interview-prep-45/day-07
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Checkpoint 1"
position: 7
estimated_minutes: 90
source:
    - 45-day-interview-roadmap.md
---
Six days in, you've covered arrays/hashing, two pointers, sliding window, binary search, stacks, and tree basics: 21 problems and five distinct patterns. A checkpoint day isn't slack time. It's where you find out which of those patterns you actually own versus which you solved by following a memorized script. Today has no new material. It's a structured audit, and the outcome should be a written list of your specific weak spots to attack in Week 2.

## Why checkpoints matter more than new content

Spaced repetition research is unambiguous: recall under mild difficulty (a day or two later, without the solution in front of you) builds durable memory far better than re-reading a solution you just wrote. A day spent re-solving without looking is worth more than a day spent passively consuming three new problems. Interviewers also routinely ask variants of problems you've already solved. If you only remember the code and not the reasoning, a slightly different phrasing will stall you.

## How to run this review

Follow this sequence, in order, for each pattern.

**1. Cold recall first.** Before opening any old code, write down (paper or a scratch file) the one-sentence trigger for each pattern: when do you reach for two pointers instead of a hash map? What makes a problem "sliding window shaped"? If you can't state the trigger without looking, that's the actual gap, not the code.

**2. Re-solve without looking.** Pick the 3 hardest problems from this week (your call on "hardest," usually Minimum Window Substring, 3Sum, and one tree problem). Set a timer matching realistic interview pace, 20-30 minutes each. Write the solution from scratch, no peeking at your Day 1-6 code.

**3. Compare, don't just check pass/fail.** If your fresh solution differs from your original in approach, not just variable names, figure out why. Did you forget the have/need trick? Did you reach for brute force before remembering the pattern? That's a specific, actionable note.

**4. Log the blind spot.** One line per weak pattern: what broke, why, what you'll do differently. This log is what makes Week 2 more effective than blindly repeating Week 1's mistakes.

## Self-assessment rubric

Rate yourself honestly on each pattern from this week. This rubric is what "review tasks" above actually means in practice.

| Pattern | Can state the trigger cold | Can code it in <20 min without notes | Know the complexity tradeoffs |
|---|---|---|---|
| Hashing (Two Sum, Anagram, Duplicate) | | | |
| Two Pointers (Palindrome, 3Sum, Container) | | | |
| Sliding Window (Stock, Substring, Min Window) | | | |
| Binary Search (basic, rotated, boundaries) | | | |
| Stacks (Parentheses, monotonic stack, Min Stack) | | | |
| Trees (traversals, Invert, Level Order) | | | |

Anything you can't check all three boxes for isn't "done." It's a candidate for re-solving today, and worth a second pass before Day 12 (DP) and Day 9 (graphs), both of which lean on solid traversal and recursion instincts from Day 6.

## Tracking metrics that actually predict interview readiness

Two numbers matter more than raw problem count.

The first is time per problem, split by phase: recognizing the pattern vs. writing the code vs. debugging edge cases. If debugging dominates your time, your issue is precision (off-by-ones, base cases), not pattern recognition. If recognition dominates, you need more exposure to problem phrasing, not more coding practice.

The second is blind-spot frequency: which specific pattern keeps reappearing in your log across multiple problems. A pattern that breaks once is bad luck. A pattern that breaks three times across the week is a structural gap that will show up again in Week 2's harder graph and DP problems, which compose on top of these fundamentals.
