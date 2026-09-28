---
kind: lesson
id_key: interview-prep-45/day-25
course: interview-prep-45
section: dsa
section_title: "Data Structures & Algorithms"
section_position: 2
title: "Math and Geometry"
position: 24
estimated_minutes: 105
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---

Think of a security guard checking IDs at a locked door: they don't need to check every single fact about you, just the one or two that actually prove who you are. Math and geometry interview problems work the same way; a handful of number-theory facts and careful index arithmetic solve almost everything. They test something different from graph or DP fluency, and they show up often as "easy-looking but easy to get subtly wrong" questions. This lesson covers primes, GCD/LCM, matrix rotation, and fast exponentiation.

## Prime numbers

A prime number is only divisible by 1 and itself. The naive check tests divisors up to `n`, but you only need to check up to `sqrt(n)`. Here's why: if `n = a * b` with both `a` and `b` greater than `sqrt(n)`, then `a * b > n`, which is a contradiction, so at least one factor must be at or below `sqrt(n)`.

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
```javascript +
function isPrime(n) {
    if (n < 2) return false;
    if (n === 2 || n === 3) return true;
    if (n % 2 === 0) return false;
    for (let i = 3; i * i <= n; i += 2) {
        if (n % i === 0) return false;
    }
    return true;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        System.out.println(isPrime(97));
    }

    static boolean isPrime(int n) {
        if (n < 2) return false;
        if (n == 2 || n == 3) return true;
        if (n % 2 == 0) return false;
        for (int i = 3; (long) i * i <= n; i += 2) {
            if (n % i == 0) return false;
        }
        return true;
    }
}
```

**Complexity:** O(sqrt(n)) per check. For checking primality of *many* numbers up to some bound N, the Sieve of Eratosthenes further down this lesson beats calling `is_prime` N separate times.

> **Remember:** you only ever need to test divisors up to `sqrt(n)`. Past that point, any factor would have to pair with one smaller than `sqrt(n)`, which you'd have already found.

```knowledge-check
{ "questions": [
    { "id": "dsa-math-primes-q1", "type": "mcq",
      "prompt": "Why does a primality check only need to test divisors up to sqrt(n), instead of all the way up to n?",
      "options": [
        {"id": "a", "text": "If n = a * b with both a and b greater than sqrt(n), then a * b would exceed n, which is a contradiction, so at least one factor must be at or below sqrt(n)"},
        {"id": "b", "text": "Because all prime numbers are less than their own square root"},
        {"id": "c", "text": "Because division is undefined for numbers larger than sqrt(n)"},
        {"id": "d", "text": "It's just a performance shortcut with no mathematical justification"}
      ],
      "correct": "a",
      "explanation": "Any factor pair of a composite n must have one factor at or below sqrt(n) and one at or above it, so checking only up to sqrt(n) is guaranteed to catch a factor if one exists." }
] }
```

## GCD and LCM

**GCD** (greatest common divisor) comes from the **Euclidean algorithm**: `gcd(a, b) = gcd(b, a % b)`, stopping when `b == 0`.

```python
def gcd(a: int, b: int) -> int:
    while b:
        a, b = b, a % b
    return a
```
```javascript +
function gcd(a, b) {
    while (b) {
        [a, b] = [b, a % b];
    }
    return a;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        System.out.println(gcd(48, 18));
    }

    static int gcd(int a, int b) {
        while (b != 0) {
            int temp = b;
            b = a % b;
            a = temp;
        }
        return a;
    }
}
```

**LCM** (least common multiple) follows directly from GCD: `lcm(a, b) = a * b / gcd(a, b)`.

```python
def lcm(a: int, b: int) -> int:
    return a * b // gcd(a, b)
```
```javascript +
function gcd(a, b) {
    while (b) {
        [a, b] = [b, a % b];
    }
    return a;
}

function lcm(a, b) {
    return (a * b) / gcd(a, b);
}
```
```java +
public class Main {
    public static void main(String[] args) {
        System.out.println(lcm(4, 6));
    }

    static int gcd(int a, int b) {
        while (b != 0) {
            int temp = b;
            b = a % b;
            a = temp;
        }
        return a;
    }

    static int lcm(int a, int b) {
        return (a * b) / gcd(a, b);
    }
}
```

**Complexity:** GCD runs in O(log(min(a, b))): each step roughly halves the smaller number in the worst case (numbers adjacent in the Fibonacci sequence are the slow case, still logarithmic). Python's standard library has `math.gcd` and `math.lcm` directly. Mention the built-in, but be ready to derive it from scratch, since implementing Euclid's algorithm is a common ask.

**Pitfall:** compute `a * b // gcd(a, b)` as written, in that order. If you're worried about overflow in a fixed-width-integer language, order of operations matters; this isn't a Python concern, but interviewers sometimes probe it anyway.

> **Remember:** `gcd(a, b) = gcd(b, a % b)`, stop at `b == 0`. LCM is just `a * b / gcd(a, b)` on top of that.

```knowledge-check
{ "questions": [
    { "id": "dsa-math-gcd-lcm-q1", "type": "mcq",
      "prompt": "What's the core recurrence behind the Euclidean algorithm for GCD?",
      "options": [
        {"id": "a", "text": "gcd(a, b) = gcd(b, a % b), stopping once b reaches 0"},
        {"id": "b", "text": "gcd(a, b) = a * b, always"},
        {"id": "c", "text": "gcd(a, b) requires factoring both numbers into primes first"},
        {"id": "d", "text": "gcd(a, b) = a - b, repeated until they're equal"}
      ],
      "correct": "a",
      "explanation": "Repeatedly replacing (a, b) with (b, a % b) shrinks the pair each step and converges to the greatest common divisor once b becomes 0." }
] }
```

## Matrix rotation

Rotating an `n x n` matrix 90 degrees clockwise **in place** (O(1) extra space) takes two steps: **transpose**, then **reverse each row**.

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
```javascript +
function rotate90Clockwise(matrix) {
    const n = matrix.length;

    // 1. transpose: swap matrix[i][j] with matrix[j][i]
    for (let i = 0; i < n; i++) {
        for (let j = i + 1; j < n; j++) {
            [matrix[i][j], matrix[j][i]] = [matrix[j][i], matrix[i][j]];
        }
    }

    // 2. reverse each row
    for (const row of matrix) {
        row.reverse();
    }
}
```
```java +
public class Main {
    public static void main(String[] args) {
        int[][] matrix = {
            {1, 2, 3},
            {4, 5, 6},
            {7, 8, 9}
        };
        rotate90Clockwise(matrix);
        for (int[] row : matrix) {
            System.out.println(java.util.Arrays.toString(row));
        }
    }

    static void rotate90Clockwise(int[][] matrix) {
        int n = matrix.length;

        // 1. transpose: swap matrix[i][j] with matrix[j][i]
        for (int i = 0; i < n; i++) {
            for (int j = i + 1; j < n; j++) {
                int temp = matrix[i][j];
                matrix[i][j] = matrix[j][i];
                matrix[j][i] = temp;
            }
        }

        // 2. reverse each row
        for (int[] row : matrix) {
            int left = 0, right = row.length - 1;
            while (left < right) {
                int temp = row[left];
                row[left] = row[right];
                row[right] = temp;
                left++;
                right--;
            }
        }
    }
}
```

Why transpose plus reverse rows equals a 90 degree clockwise turn: transposing flips the matrix across its main diagonal, turning rows into columns. Reversing each row then flips left-right, and the two combined equal a clockwise quarter turn. Trace a 3x3 example by hand once; it's much easier to verify visually than to reason about in the abstract.

The alternative **4-way (layer-by-layer) swap** rotates the outer ring, then the next ring inward, cycling four cells at a time (`top -> right -> bottom -> left -> top`). Both approaches hit O(1) extra space. Transpose-plus-reverse is shorter to write correctly under pressure, so default to it unless the interviewer specifically wants the layer-cycling version.

> **Remember:** transpose flips across the diagonal, reversing each row flips left-right. Do both, in that order, and you've rotated 90 degrees clockwise in place.

```knowledge-check
{ "questions": [
    { "id": "dsa-math-matrix-rotation-q1", "type": "mcq",
      "prompt": "What two steps rotate an n x n matrix 90 degrees clockwise in place?",
      "options": [
        {"id": "a", "text": "Transpose the matrix (swap across the main diagonal), then reverse each row"},
        {"id": "b", "text": "Reverse each row, then reverse each column"},
        {"id": "c", "text": "Sort each row in ascending order, then transpose"},
        {"id": "d", "text": "Allocate a brand-new matrix and copy every value into its rotated position"}
      ],
      "correct": "a",
      "explanation": "Transposing turns rows into columns; reversing each row afterward completes the clockwise quarter turn, and both steps together use only O(1) extra space." }
] }
```

### Rotate Image

[LeetCode 48](https://leetcode.com/problems/rotate-image/) — Matrix

**Intuition:** A direct application of the transpose-plus-reverse-rows technique above. This problem *is* that technique, asked standalone.

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
```javascript +
function rotate(matrix) {
    const n = matrix.length;
    for (let i = 0; i < n; i++) {
        for (let j = i + 1; j < n; j++) {
            [matrix[i][j], matrix[j][i]] = [matrix[j][i], matrix[i][j]];
        }
    }
    for (const row of matrix) {
        row.reverse();
    }
}
```
```java +
public class Main {
    public static void main(String[] args) {
        int[][] matrix = {
            {1, 2, 3},
            {4, 5, 6},
            {7, 8, 9}
        };
        rotate(matrix);
        for (int[] row : matrix) {
            System.out.println(java.util.Arrays.toString(row));
        }
    }

    static void rotate(int[][] matrix) {
        int n = matrix.length;
        for (int i = 0; i < n; i++) {
            for (int j = i + 1; j < n; j++) {
                int temp = matrix[i][j];
                matrix[i][j] = matrix[j][i];
                matrix[j][i] = temp;
            }
        }
        for (int[] row : matrix) {
            int left = 0, right = row.length - 1;
            while (left < right) {
                int temp = row[left];
                row[left] = row[right];
                row[right] = temp;
                left++;
                right--;
            }
        }
    }
}
```

**Complexity:** Time O(n²), space O(1); the whole point of this problem is the in-place constraint.

**Common mistakes:** transposing the full `n x n` range instead of only the upper triangle (`j in range(i+1, n)`), which transposes twice and undoes the operation. Also, allocating a new matrix and copying rotated values in, which works but violates the "in place" requirement the problem is explicitly testing.

> **Remember:** only swap the upper triangle when transposing. Swapping the whole matrix undoes itself.

### Spiral Matrix

[LeetCode 54](https://leetcode.com/problems/spiral-matrix/) — Matrix

**Intuition:** Walk the matrix in a shrinking rectangular spiral: right across the top row, down the right column, left across the bottom row, up the left column, then shrink the boundary and repeat.

**Approach:** Maintain four boundaries (`top`, `bottom`, `left`, `right`). Traverse each side in order, then move the corresponding boundary inward. Stop when the boundaries cross.

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
```javascript +
function spiralOrder(matrix) {
    if (matrix.length === 0) return [];

    const result = [];
    let top = 0, bottom = matrix.length - 1;
    let left = 0, right = matrix[0].length - 1;

    while (top <= bottom && left <= right) {
        for (let col = left; col <= right; col++) {
            result.push(matrix[top][col]);
        }
        top++;

        for (let row = top; row <= bottom; row++) {
            result.push(matrix[row][right]);
        }
        right--;

        if (top <= bottom) {
            for (let col = right; col >= left; col--) {
                result.push(matrix[bottom][col]);
            }
            bottom--;
        }

        if (left <= right) {
            for (let row = bottom; row >= top; row--) {
                result.push(matrix[row][left]);
            }
            left++;
        }
    }

    return result;
}
```
```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        int[][] matrix = {
            {1, 2, 3},
            {4, 5, 6},
            {7, 8, 9}
        };
        System.out.println(spiralOrder(matrix));
    }

    static List<Integer> spiralOrder(int[][] matrix) {
        List<Integer> result = new ArrayList<>();
        if (matrix.length == 0) return result;

        int top = 0, bottom = matrix.length - 1;
        int left = 0, right = matrix[0].length - 1;

        while (top <= bottom && left <= right) {
            for (int col = left; col <= right; col++) {
                result.add(matrix[top][col]);
            }
            top++;

            for (int row = top; row <= bottom; row++) {
                result.add(matrix[row][right]);
            }
            right--;

            if (top <= bottom) {
                for (int col = right; col >= left; col--) {
                    result.add(matrix[bottom][col]);
                }
                bottom--;
            }

            if (left <= right) {
                for (int row = bottom; row >= top; row--) {
                    result.add(matrix[row][left]);
                }
                left++;
            }
        }

        return result;
    }
}
```

**Complexity:** Time O(rows x cols), since every cell is visited exactly once. Space O(1) extra (excluding the output list).

**Common mistakes:** leaving out the `if top <= bottom` / `if left <= right` guards before the bottom-row and left-column traversals. Without them, a single-row or single-column matrix gets its edge cells double-counted. Also, an off-by-one on boundary updates: `top += 1` happens after finishing the top row, not before.

> **Remember:** four shrinking boundaries, four directions. The two guard checks before the last two sides are what stop a thin matrix from double-counting cells.

### Count Primes

[LeetCode 204](https://leetcode.com/problems/count-primes/) — Math

**Intuition:** Counting primes below `n` one by one with `is_prime` is O(n sqrt(n)), too slow for large n. The **Sieve of Eratosthenes** flips the approach: instead of testing each number for primality, start with everything marked "possibly prime" and cross out multiples of each prime as you find one, in O(n log log n) total.

**Approach:** Build a boolean array of size `n`, all `True` initially. Starting from 2, for every number still marked prime, cross out all its multiples. Count the remaining `True` entries.

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
```javascript +
function countPrimes(n) {
    if (n < 3) return 0;

    const isPrimeArr = new Array(n).fill(true);
    isPrimeArr[0] = isPrimeArr[1] = false;

    for (let i = 2; i * i <= n; i++) {
        if (isPrimeArr[i]) {
            for (let multiple = i * i; multiple < n; multiple += i) { // start at i*i: smaller multiples already crossed out
                isPrimeArr[multiple] = false;
            }
        }
    }

    return isPrimeArr.filter(Boolean).length;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        System.out.println(countPrimes(20));
    }

    static int countPrimes(int n) {
        if (n < 3) return 0;

        boolean[] isPrimeArr = new boolean[n];
        java.util.Arrays.fill(isPrimeArr, true);
        isPrimeArr[0] = isPrimeArr[1] = false;

        for (int i = 2; (long) i * i <= n; i++) {
            if (isPrimeArr[i]) {
                for (int multiple = i * i; multiple < n; multiple += i) { // start at i*i: smaller multiples already crossed out
                    isPrimeArr[multiple] = false;
                }
            }
        }

        int count = 0;
        for (boolean prime : isPrimeArr) {
            if (prime) count++;
        }
        return count;
    }
}
```

**Complexity:** Time O(n log log n), space O(n).

**Common mistakes:** starting the inner crossing-out loop at `2*i` instead of `i*i`. Both are correct, but `i*i` is the standard optimization since smaller multiples of `i` were already crossed out by smaller primes. Also, forgetting the outer loop only needs to run up to `sqrt(n)`: any composite number below n has a factor at or below `sqrt(n)`, so all composites are caught by then.

**A closely related task:** you may be asked to return the actual list of primes, not just a count. The sieve barely changes: instead of summing the boolean array, collect the indices where it's still `True`.

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
```javascript +
function sieveOfEratosthenes(n) {
    // Return all primes strictly less than n.
    if (n < 3) return [];

    const isPrimeArr = new Array(n).fill(true);
    isPrimeArr[0] = isPrimeArr[1] = false;

    for (let i = 2; i * i <= n; i++) {
        if (isPrimeArr[i]) {
            for (let multiple = i * i; multiple < n; multiple += i) {
                isPrimeArr[multiple] = false;
            }
        }
    }

    return isPrimeArr.reduce((primes, isPrime, i) => {
        if (isPrime) primes.push(i);
        return primes;
    }, []);
}
```
```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        System.out.println(sieveOfEratosthenes(20));
    }

    // Return all primes strictly less than n.
    static List<Integer> sieveOfEratosthenes(int n) {
        if (n < 3) return new ArrayList<>();

        boolean[] isPrimeArr = new boolean[n];
        Arrays.fill(isPrimeArr, true);
        isPrimeArr[0] = isPrimeArr[1] = false;

        for (int i = 2; (long) i * i <= n; i++) {
            if (isPrimeArr[i]) {
                for (int multiple = i * i; multiple < n; multiple += i) {
                    isPrimeArr[multiple] = false;
                }
            }
        }

        List<Integer> primes = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            if (isPrimeArr[i]) primes.add(i);
        }
        return primes;
    }
}
```

> **Remember:** don't test each number for primality one at a time. Cross out multiples of every prime you find, and everything left standing is prime.

### Pow(x, n)

[LeetCode 50](https://leetcode.com/problems/powx-n/) — Math — Binary exponentiation

**Intuition:** Computing `x^n` by multiplying `x` by itself `n` times is O(n). **Binary (fast) exponentiation** uses `x^n = (x^(n//2))^2`, times an extra `x` if `n` is odd, to halve the problem size at every step, giving O(log n).

**Approach:** Repeatedly square the base and halve the exponent, either recursively or iteratively. Handle negative exponents by inverting at the start (`x^-n = 1 / x^n`).

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
```javascript +
function myPow(x, n) {
    if (n < 0) {
        x = 1 / x;
        n = -n;
    }

    let result = 1;
    while (n > 0) {
        if (n % 2 === 1) {
            result *= x;
        }
        x *= x;
        n = Math.floor(n / 2);
    }

    return result;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        System.out.println(myPow(2.0, 10));
    }

    static double myPow(double x, int n) {
        long exponent = n;
        if (exponent < 0) {
            x = 1 / x;
            exponent = -exponent;
        }

        double result = 1;
        while (exponent > 0) {
            if (exponent % 2 == 1) {
                result *= x;
            }
            x *= x;
            exponent /= 2;
        }

        return result;
    }
}
```

**Complexity:** Time O(log n), space O(1) for the iterative version; the recursive version is O(log n) time but O(log n) space for the call stack.

**Common mistakes:** the naive O(n) repeated-multiplication approach is correct but too slow, so always mention the fast-exponentiation follow-up even if you start with the naive version. Also, mishandling `n = 0` (any `x^0 = 1`, including `0^0` by this problem's convention) or negative `n` (invert `x` and negate `n` *before* the loop, not after). Floating-point precision drift on very large `n` is acceptable for LeetCode's tolerance, but worth naming as a real-world caveat.

> **Remember:** squaring the base and halving the exponent turns O(n) multiplications into O(log n). The same trick powers matrix exponentiation and modular exponentiation elsewhere in computing.

### Reverse Integer

[LeetCode 7 · Reverse Integer](https://leetcode.com/problems/reverse-integer/) — Math — Overflow handling

**Intuition:** Reverse the digits of a 32-bit signed integer, returning `0` if the result would overflow `[-2^31, 2^31 - 1]`. It's the same shape of problem as `Pow(x, n)`'s overflow question above: the naive version works fine, and the interview is really about handling overflow and edge cases correctly.

**Approach 1: string conversion.** Works, but relies on string allocation, and only catches overflow *after the fact*, since Python integers are unbounded. Most interviewers push you toward the math approach next.

```python
def reverse_v1(x: int) -> int:
    sign = -1 if x < 0 else 1
    rev = int(str(abs(x))[::-1]) * sign
    return rev if -(2**31) <= rev <= 2**31 - 1 else 0
```

**Approach 2: digit extraction with an overflow check before it happens.** This is the answer interviewers are actually looking for.

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

**Why check before, not after:** in a language with fixed-width integers (Java, C++), `result * 10 + digit` overflows *during* the computation. By the time you could check the result, it's already wrong: undefined behavior in C++, silent wraparound in Java. Checking `result > INT_MAX // 10` beforehand, since that condition means the next multiply would overflow, avoids ever computing the bad value.

**Why `digit > 7` specifically:** `2^31 - 1 = 2147483647`, and its last digit is `7`. If `result == INT_MAX // 10` exactly, the only digit that keeps the result in bounds is 7 or less; anything higher overflows.

**Complexity:** Time O(log10 x), one iteration per digit. Space O(1).

**Common mistakes:** treating this as a Python-only problem and skipping the overflow check, since Python integers never overflow on their own. State the portability point out loud: a Python-only solution could reverse first and clamp after, and it would still pass this problem's tests. But that wouldn't hold up in Java or C++, where the multiply-add itself overflows before you get a chance to check anything. Approach 2's before-the-fact check is the one that translates directly to a fixed-width-integer language, and that's usually what the interviewer is actually testing.

> **Remember:** check for overflow before the operation that would cause it, not after. In a fixed-width language, "after" is already too late.
