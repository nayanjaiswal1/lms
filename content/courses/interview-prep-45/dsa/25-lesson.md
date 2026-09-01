---
kind: lesson
id_key: interview-prep-45/day-25
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Math and Geometry"
position: 25
estimated_minutes: 105
source:
    - 45-day-interview-roadmap.md
---

Math and geometry problems test something different from graph/DP fluency: careful index arithmetic and knowing a handful of classic number-theory tricks. They come up often as "easy-looking but easy to get subtly wrong" interview questions. Today covers primes, GCD/LCM, matrix rotation, and fast exponentiation.

## Prime numbers

A prime is only divisible by 1 and itself. The naive check tests divisors up to `n`, but you only need to check up to `sqrt(n)`. Here's why: if `n = a * b` with both `a, b > sqrt(n)`, then `a * b > n`, a contradiction, so at least one factor must be ≤ `sqrt(n)`.

```python
def is_prime(n: int) -> bool:
    if n < 2:
        return False
    if n in (2, 3):
        return True
    if n % 2 == 0:
        return False
    i = 3
    while i * i <= n:
        if n % i == 0:
            return False
        i += 2
    return True
```

**Complexity:** O(sqrt(n)) per check. For checking primality of *many* numbers up to some bound N, the Sieve of Eratosthenes (below) is far better than calling `is_prime` N times.

## GCD/LCM

**GCD** (greatest common divisor) via the **Euclidean algorithm**: `gcd(a, b) = gcd(b, a % b)`, terminating when `b == 0`.

```python
def gcd(a: int, b: int) -> int:
    while b:
        a, b = b, a % b
    return a
```

**LCM** (least common multiple) derives directly from GCD: `lcm(a, b) = a * b / gcd(a, b)`.

```python
def lcm(a: int, b: int) -> int:
    return a * b // gcd(a, b)
```

**Complexity:** GCD is O(log(min(a, b))): each step roughly halves the smaller number in the worst case (Fibonacci-adjacent numbers are the slow case, still logarithmic). Python's stdlib has `math.gcd` and `math.lcm` directly. Mention the built-in, but be ready to derive it from scratch, since implementing Euclid's algorithm is a common ask.

**Pitfall:** compute `a * b // gcd(a, b)`, not `(a * b) // gcd(a, b)` after already reducing. Order of operations matters if you're trying to avoid overflow in a fixed-width-integer language. Not a Python concern, but interviewers sometimes probe this.

## Matrix rotation

Rotating an `n x n` matrix 90° clockwise **in place** (O(1) extra space) is done in two steps: **transpose**, then **reverse each row**.

```python
def rotate_90_clockwise(matrix: list[list[int]]) -> None:
    n = len(matrix)

    # 1. transpose: swap matrix[i][j] with matrix[j][i]
    for i in range(n):
        for j in range(i + 1, n):
            matrix[i][j], matrix[j][i] = matrix[j][i], matrix[i][j]

    # 2. reverse each row
    for row in matrix:
        row.reverse()
```

Why transpose + reverse rows equals 90° clockwise: transposing flips the matrix across its main diagonal, turning rows into columns. Reversing each row then flips left-right, and the two combined equal a clockwise quarter turn. Trace a 3x3 example by hand once; it's much easier to verify visually than to reason about abstractly.

The alternative **4-way (layer-by-layer) swap** rotates the outer ring, then the next ring inward, cycling four cells at a time (`top -> right -> bottom -> left -> top`). Both achieve O(1) extra space. Transpose+reverse is shorter to write correctly under pressure, so default to it unless the interviewer specifically wants the layer-cycling approach.

## Rotate Image

[LeetCode 48](https://leetcode.com/problems/rotate-image/) — Matrix

**Intuition:** Direct application of the transpose + reverse-rows technique from the concept section. This problem *is* that technique, asked standalone.

**Approach:** Transpose in place, then reverse each row in place.

```python
def rotate(matrix: list[list[int]]) -> None:
    n = len(matrix)
    for i in range(n):
        for j in range(i + 1, n):
            matrix[i][j], matrix[j][i] = matrix[j][i], matrix[i][j]
    for row in matrix:
        row.reverse()
```

**Complexity:** Time O(n²), space O(1); the whole point of this problem is the in-place constraint.

**Common mistakes:** Transposing the full `n x n` range instead of only the upper triangle (`j in range(i+1, n)`), which transposes twice and undoes the operation. Also, allocating a new matrix and copying rotated values in, which works but violates the "in place" requirement the problem explicitly tests for.

## Spiral Matrix

[LeetCode 54](https://leetcode.com/problems/spiral-matrix/) — Matrix

**Intuition:** Walk the matrix in a shrinking rectangular spiral: right across the top row, down the right column, left across the bottom row, up the left column, then shrink the boundary and repeat.

**Approach:** Maintain four boundaries (`top`, `bottom`, `left`, `right`). Traverse each side in order, then move the corresponding boundary inward. Stop when boundaries cross.

```python
def spiralOrder(matrix: list[list[int]]) -> list[int]:
    if not matrix:
        return []

    result = []
    top, bottom = 0, len(matrix) - 1
    left, right = 0, len(matrix[0]) - 1

    while top <= bottom and left <= right:
        for col in range(left, right + 1):
            result.append(matrix[top][col])
        top += 1

        for row in range(top, bottom + 1):
            result.append(matrix[row][right])
        right -= 1

        if top <= bottom:
            for col in range(right, left - 1, -1):
                result.append(matrix[bottom][col])
            bottom -= 1

        if left <= right:
            for row in range(bottom, top - 1, -1):
                result.append(matrix[row][left])
            left -= 1

    return result
```

**Complexity:** Time O(rows × cols), since every cell is visited exactly once. Space O(1) extra (excluding the output list).

**Common mistakes:** Omitting the `if top <= bottom` / `if left <= right` guards before the bottom-row and left-column traversals. Without them, a single-row or single-column matrix gets its edge cells double-counted. Also, off-by-one on boundary updates (`top += 1` after finishing the top row, not before).

## Count Primes

[LeetCode 204](https://leetcode.com/problems/count-primes/) — Math

**Intuition:** Counting primes below `n` one-by-one with `is_prime` is O(n·sqrt(n)), too slow for large n. The **Sieve of Eratosthenes** flips this: instead of testing each number for primality, start with everything marked "possibly prime" and cross out multiples of each prime as you find one, in O(n log log n) total.

**Approach:** Build a boolean array of size `n`, all `True` initially. Starting from 2, for every number still marked prime, cross out all its multiples. Count remaining `True` entries.

```python
def countPrimes(n: int) -> int:
    if n < 3:
        return 0

    is_prime_arr = [True] * n
    is_prime_arr[0] = is_prime_arr[1] = False

    for i in range(2, int(n ** 0.5) + 1):
        if is_prime_arr[i]:
            for multiple in range(i * i, n, i):  # start at i*i: smaller multiples already crossed out
                is_prime_arr[multiple] = False

    return sum(is_prime_arr)
```

**Complexity:** Time O(n log log n), space O(n).

**Common mistakes:** Starting the inner crossing-out loop at `2*i` instead of `i*i` is correct either way, but `i*i` is the standard optimization since smaller multiples of `i` were already crossed out by smaller primes. Also, forgetting the outer loop only needs to run up to `sqrt(n)`: any composite number below n has a factor ≤ sqrt(n), so all composites are caught by then.

## Sieve of Eratosthenes (implementation)

Referenced as a standalone implementation task: the full sieve, returning the list of primes rather than just a count.

```python
def sieve_of_eratosthenes(n: int) -> list[int]:
    """Return all primes strictly less than n."""
    if n < 3:
        return []

    is_prime_arr = [True] * n
    is_prime_arr[0] = is_prime_arr[1] = False

    for i in range(2, int(n ** 0.5) + 1):
        if is_prime_arr[i]:
            for multiple in range(i * i, n, i):
                is_prime_arr[multiple] = False

    return [i for i, prime in enumerate(is_prime_arr) if prime]
```

## Pow(x, n)

[LeetCode 50](https://leetcode.com/problems/powx-n/) — Math — Binary exponentiation

**Intuition:** Computing `x^n` by multiplying `x` by itself `n` times is O(n). **Binary (fast) exponentiation** exploits `x^n = (x^(n//2))^2`, times an extra `x` if `n` is odd, to halve the problem size at every step, giving O(log n).

**Approach:** Recursively (or iteratively) square the base and halve the exponent. Handle negative exponents by inverting at the start (`x^-n = 1 / x^n`).

```python
def myPow(x: float, n: int) -> float:
    if n < 0:
        x = 1 / x
        n = -n

    result = 1
    while n > 0:
        if n % 2 == 1:
            result *= x
        x *= x
        n //= 2

    return result
```

**Complexity:** Time O(log n), space O(1) for the iterative version; the recursive version is O(log n) time but O(log n) space for the call stack.

**Common mistakes:** Naive O(n) repeated multiplication is correct but too slow, so always mention the fast-exponentiation follow-up even if you start with the naive version. Mishandling `n = 0` (any `x^0 = 1`, including `0^0` by this problem's convention) or negative `n` (invert `x` and negate `n` *before* the loop, not after) is another common slip. Floating-point precision drift on very large `n` is acceptable for LeetCode's tolerance, but worth naming as a real-world caveat.

Binary exponentiation isn't a one-off trick. The same squaring-and-halving idea reappears whenever you need to raise something to a large power fast: matrix exponentiation for linear recurrences, modular exponentiation in cryptography. Once you've internalized it here, you'll recognize it everywhere.
