---
kind: lesson
id_key: interview-prep-45/day-20
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Day 20 — Bit Manipulation"
position: 20
estimated_minutes: 150
source:
    - 45-day-interview-roadmap.md
---
Bit manipulation problems test whether you understand what's actually happening at the machine level under Python's integer abstraction. They come up because a handful of XOR/AND/OR tricks turn O(n) extra-space problems into O(1) space ones — and because interviewers use them as a quick signal for CS fundamentals depth.

## Bitwise operations

The core operators and what they mean bit-by-bit:

```python
a & b   # AND: 1 only where both bits are 1  — used for masking / checking a bit
a | b   # OR:  1 where either bit is 1        — used for setting a bit
a ^ b   # XOR: 1 where bits differ            — used for toggling / finding differences
~a      # NOT: flips every bit                — in Python, ~a == -a - 1 (two's complement)
a << k  # left shift: multiply by 2^k
a >> k  # right shift: divide by 2^k (floor, arithmetic shift for negative ints in Python)
```

Useful bit-twiddling idioms to have memorized:

```python
n & (n - 1)     # clears the lowest set bit — used to count set bits, check power of 2
n & (-n)        # isolates the lowest set bit
n | (1 << k)    # sets bit k
n & ~(1 << k)   # clears bit k
n ^ (1 << k)    # toggles bit k
(n >> k) & 1    # reads bit k
```

`n & (n - 1) == 0` (for `n > 0`) is the fastest power-of-2 check: a power of 2 has exactly one set bit, and subtracting 1 flips every bit below it, so ANDing them together always yields zero.

## Two's complement

Negative integers are represented as two's complement in essentially every language with fixed-width integers: to negate `n`, flip all bits and add 1 (`~n + 1 == -n`). This is why `~a == -a - 1` in Python even though Python integers are conceptually arbitrary-precision — Python still models bitwise NOT as if operating on an infinite two's-complement representation.

Python has a quirk you need to know for interviews: unlike Java/C++, Python integers don't have a fixed bit width, so operations like `n >> 1` on a negative number keep sign-extending forever, and there's no native 32-bit overflow wraparound. Problems like Reverse Bits and Sum of Two Integers explicitly need you to *simulate* fixed-width behavior with masking:

```python
MASK32 = 0xFFFFFFFF   # mask to simulate a 32-bit unsigned register

def to_signed_32(n: int) -> int:
    n &= MASK32
    # if the sign bit (bit 31) is set, interpret as negative
    return n if n < 0x80000000 else n - 0x100000000
```

## Common patterns

**XOR self-cancellation** (`a ^ a == 0`, `a ^ 0 == a`, XOR is commutative and associative): XOR-ing an array where every element appears twice except one leaves only the unpaired element, because every pair cancels to 0. This is the entire trick behind Single Number.

**Counting set bits**: `n & (n - 1)` repeatedly clears the lowest set bit — loop until `n == 0`, counting iterations. This runs in O(popcount) time rather than O(32) for checking every bit position, which matters when `n` is sparse.

**Missing number via XOR**: XOR-ing `0..n` with all elements of an `n`-length array (missing exactly one value from `0..n`) cancels every present value, leaving the missing one — avoids the overflow risk of a sum-based approach (`n*(n+1)/2 - sum(nums)`), which matters in fixed-width-integer languages even though it's a non-issue in Python.

### Number of 1 Bits

[LeetCode 191 — Number of 1 Bits](https://leetcode.com/problems/number-of-1-bits/) — Bit — Hamming weight

**Intuition:** Count set bits by repeatedly clearing the lowest one with `n & (n - 1)` until `n` becomes 0 — the number of clears equals the number of set bits.

**Approach:** Loop while `n != 0`; each iteration does `n &= n - 1` and increments a counter.

```python
def hamming_weight(n: int) -> int:
    count = 0
    while n:
        n &= n - 1   # clears the lowest set bit
        count += 1
    return count
```

**Complexity:** O(k) time where `k` is the number of set bits (not 32) — better than a naive O(32) bit-by-bit scan on sparse inputs. O(1) space.

**Common mistakes:** using `n >>= 1` combined with `n & 1` in a fixed 32-iteration loop — correct but strictly worse than the `n & (n-1)` trick when bits are sparse; forgetting Python has no fixed width, so a naive right-shift loop on a value treated as "signed 32-bit" needs masking to behave correctly (LeetCode passes this as an unsigned int specifically to sidestep that issue).

### Reverse Bits

[LeetCode 190 — Reverse Bits](https://leetcode.com/problems/reverse-bits/) — Bit — Bit swapping

**Intuition:** Build the result bit by bit: take the lowest bit of the input, place it as the highest bit of the output (shifted into position), then shift the input right and repeat for all 32 positions.

**Approach:** Loop 32 times; each iteration extracts `n`'s lowest bit, shifts it into the correct position of `result`, then shifts `n` right by one.

```python
def reverse_bits(n: int) -> int:
    result = 0
    for i in range(32):
        bit = (n >> i) & 1
        result |= bit << (31 - i)
    return result
```

**Complexity:** O(32) = O(1) time (fixed width), O(1) space.

**Common mistakes:** forgetting the loop must run exactly 32 times regardless of how many leading zero bits `n` has — this is a fixed-width problem, not a variable-length one; off-by-one in the shift amount (`31 - i`, not `32 - i`).

### Single Number

[LeetCode 136 — Single Number](https://leetcode.com/problems/single-number/) — Bit — XOR trick

**Intuition:** Every element except one appears exactly twice. XOR-ing the entire array cancels every paired element to 0, leaving only the unpaired one, since XOR is commutative/associative so the order pairs cancel in doesn't matter.

**Approach:** Single pass, XOR-accumulate into a running result.

```python
def single_number(nums: list[int]) -> int:
    result = 0
    for num in nums:
        result ^= num
    return result
```

**Complexity:** O(n) time, O(1) space — strictly better than a hash-set approach (O(n) space) which is the "obvious" first instinct.

**Common mistakes:** reaching for a `Counter`/hash-set solution first without recognizing the O(1)-space XOR trick applies whenever "every element appears twice except one" is the setup; trying to force the XOR trick onto a variant where elements appear *three* times except one (LeetCode 137) — that needs a different bit-counting technique, XOR alone doesn't work there.

### Missing Number

[LeetCode 268 — Missing Number](https://leetcode.com/problems/missing-number/) — Bit — XOR

**Intuition:** An array of length `n` contains distinct values from `0` to `n`, missing exactly one. XOR every array value together with every value from `0` to `n` inclusive — every present number cancels with its own index/value pairing, leaving only the missing number.

**Approach:** Initialize `result = n` (accounts for the index-`n` term that has no corresponding array index), then XOR in `i ^ nums[i]` for each index.

```python
def missing_number(nums: list[int]) -> int:
    result = len(nums)   # pre-seed with n, since indices only go 0..n-1
    for i, num in enumerate(nums):
        result ^= i ^ num
    return result
```

**Complexity:** O(n) time, O(1) space.

**Common mistakes:** using the arithmetic sum formula (`n*(n+1)//2 - sum(nums)`) — this works fine in Python but is worth contrasting with XOR: in fixed-width-integer languages, the sum formula risks overflow for large `n`, while XOR never does, which is why XOR is the "safer general" answer even though both are O(n)/O(1) in Python; miscounting the range (must XOR indices `0..n-1` plus values, seeded with `n`, not `0..n`).

## Key takeaways

- `n & (n - 1)` clears the lowest set bit — the basis for fast popcount and power-of-2 checks.
- XOR self-cancellation (`a ^ a = 0`) is the single most reused bit trick in interviews: "find the unpaired element" problems almost always reduce to it.
- Python has no fixed integer width — problems that assume 32-bit behavior (Reverse Bits, signed overflow) need explicit masking to simulate it.
- Fixed-width problems (Reverse Bits) loop a constant 32 times; sparse-bit problems (popcount) should loop only as many times as there are set bits, not 32.
- XOR-based solutions are safer than sum-based arithmetic tricks in languages with fixed-width overflow, even when both work fine in Python.
- Always check whether "appears twice except one" (XOR works) vs. "appears three times except one" (XOR alone fails, needs a different technique) before applying the trick.

## Today's checklist

- [ ] Solve Number of 1 Bits (LeetCode 191)
- [ ] Solve Reverse Bits (LeetCode 190)
- [ ] Solve Single Number (LeetCode 136)
- [ ] Solve Missing Number (LeetCode 268)
- [ ] Implement all four core bit operations (set/clear/toggle/read a bit) from scratch
- [ ] Practice the XOR properties: a^a=0, a^0=a, commutative, associative
- [ ] Memorize: XOR a^a = 0, a^0 = a
- [ ] Review how to count set bits efficiently with n & (n-1)
