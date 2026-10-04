---
kind: lesson
id_key: advanced-python-interview/core-language/numbers-bases-floats
course: advanced-python-interview
section: core-language
section_title: "Core Language"
section_position: 0
section_group: Fundamentals
title: "Numbers: Base Conversion & Float Comparison"
position: 1
estimated_minutes: 10
source: ["knowledge/backend/python/python-core.md"]
---
Two staple warm-up questions: convert a number between bases, and explain why `0.1 + 0.2 != 0.3`. Both have short, precise answers.

## Converting between number bases

`bin`, `oct` and `hex` turn an int into a **string** with a `0b`/`0o`/`0x` prefix. `int(text, base)` goes the other way. To convert between two non-decimal bases, go through an int.

```python
print(bin(10), oct(10), hex(10))   # 0b1010 0o12 0xa
print(int("1010", 2), int("12", 8), int("a", 16))  # 10 10 10
print(hex(int("1010", 2)))         # 0xa
print(bin(10)[2:])                 # 1010
```

`format()` avoids the prefix and controls case and padding.

```python
print(format(10, 'b'))     # 1010
print(format(10, 'X'))     # A
print(format(10, '#010b')) # 0b00001010
```

```knowledge-check
{
  "questions": [
    {
      "id": "core-language-bases-q1",
      "type": "mcq",
      "prompt": "What does `int(\"a\", 16)` return?",
      "options": [
        { "id": "a", "text": "10" },
        { "id": "b", "text": "'0xa'" },
        { "id": "c", "text": "ValueError" },
        { "id": "d", "text": "16" }
      ],
      "correct": "a",
      "explanation": "int(text, base) parses the string in the given base and returns a decimal int; hex digit 'a' is 10."
    },
    {
      "id": "core-language-bases-q2",
      "type": "mcq",
      "prompt": "Which call returns the binary digits of 10 without the `0b` prefix?",
      "options": [
        { "id": "a", "text": "bin(10)" },
        { "id": "b", "text": "format(10, 'b')" },
        { "id": "c", "text": "int(10, 2)" },
        { "id": "d", "text": "hex(10)" }
      ],
      "correct": "b",
      "explanation": "bin() keeps the prefix; format(10, 'b') returns '1010'. int(10, 2) is invalid because the first argument must be a string when a base is given."
    }
  ]
}
```

## Infinity as a sentinel

`float("inf")` (or the clearer `math.inf`) compares greater than every number, which makes it the natural starting value when tracking a running minimum. It exists only for floats: converting it to int fails.

```python
import math

smallest = math.inf
for n in [7, 3, 9]:
    smallest = min(smallest, n)
print(smallest)  # 3

print(math.inf > 10**100)  # True
try:
    int(float("inf"))
except OverflowError as e:
    print(e)  # cannot convert float infinity to integer
```

```knowledge-check
{
  "questions": [
    {
      "id": "core-language-inf-q1",
      "type": "mcq",
      "prompt": "What does `int(float(\"inf\"))` do?",
      "options": [
        { "id": "a", "text": "Returns a very large int" },
        { "id": "b", "text": "Returns 0" },
        { "id": "c", "text": "Raises OverflowError" },
        { "id": "d", "text": "Returns None" }
      ],
      "correct": "c",
      "explanation": "Infinity has no integer representation, so the conversion raises OverflowError."
    }
  ]
}
```

## Comparing floats safely

Floats are binary approximations, so many decimal fractions are not exact. Comparing with `==` is a bug waiting to happen. Use `math.isclose`, which applies a relative tolerance (default `1e-09`).

```python
import math

print(0.1 + 0.2)                 # 0.30000000000000004
print(0.1 + 0.2 == 0.3)          # False
print(math.isclose(0.1 + 0.2, 0.3))  # True
```

The default is purely relative, so values near zero need an absolute tolerance too.

```python
import math

print(math.isclose(1e-10, 2e-10))                 # False
print(math.isclose(1e-10, 2e-10, abs_tol=1e-9))   # True
```

```knowledge-check
{
  "questions": [
    {
      "id": "core-language-isclose-q1",
      "type": "mcq",
      "prompt": "Why is `0.1 + 0.2 == 0.3` False in Python?",
      "options": [
        { "id": "a", "text": "Python's + operator is imprecise for small numbers" },
        { "id": "b", "text": "0.1 and 0.2 cannot be represented exactly in binary floating point, so the sum is slightly off 0.3" },
        { "id": "c", "text": "Floats are stored as strings" },
        { "id": "d", "text": "== always fails on floats" }
      ],
      "correct": "b",
      "explanation": "IEEE-754 binary floats approximate most decimal fractions; the sum is 0.30000000000000004. Use math.isclose instead of ==."
    },
    {
      "id": "core-language-isclose-q2",
      "type": "mcq",
      "prompt": "When comparing numbers very close to zero with `math.isclose`, what should you add?",
      "options": [
        { "id": "a", "text": "rel_tol=0" },
        { "id": "b", "text": "An abs_tol value" },
        { "id": "c", "text": "round() on both sides to 0 digits" },
        { "id": "d", "text": "Nothing; the default always works" }
      ],
      "correct": "b",
      "explanation": "The default tolerance is relative, which is useless near zero; abs_tol sets a fixed allowed difference."
    }
  ]
}
```

## Decimal for money

When exact decimal arithmetic is required, such as currency, use `decimal.Decimal`. Always build it from a **string**: building from a float captures the float's inexact value.

```python
from decimal import Decimal

print(Decimal('0.1') + Decimal('0.2') == Decimal('0.3'))  # True
print(Decimal(0.1))
# 0.1000000000000000055511151231257827021181583404541015625
```

Another common approach for money is integer minor units (paise or cents), which avoids fractions entirely.

```knowledge-check
{
  "questions": [
    {
      "id": "core-language-decimal-q1",
      "type": "mcq",
      "prompt": "Which is the correct way to create an exact Decimal for 0.1?",
      "options": [
        { "id": "a", "text": "Decimal(0.1)" },
        { "id": "b", "text": "Decimal('0.1')" },
        { "id": "c", "text": "Decimal(1) / 10.0" },
        { "id": "d", "text": "float(Decimal(0.1))" }
      ],
      "correct": "b",
      "explanation": "Decimal(0.1) faithfully copies the float's binary error. Passing a string preserves the exact decimal value."
    }
  ]
}
```

## Original notes

Your original wording from the Notes vault, kept verbatim for reference.

#### Number base conversion

```text
# Decimal → other (always returns a string)
bin(10)   # '0b1010'
oct(10)   # '0o12'
hex(10)   # '0xa'

# Other → decimal
int("1010", 2)  # 10
int("12", 8)    # 10
int("a", 16)    # 10 — letters are valid in hex

# Any → any, via decimal
hex(int("1010", 2))  # '0xa'
bin(int("a", 16))    # '0b1010'

# Strip the 0b/0o/0x prefix
bin(10)[2:]  # '1010'

# format() as an alternative
format(10, 'b')  # '1010'
format(10, 'X')  # 'A' (uppercase hex)
```

`float("inf")` / `float("-inf")` give IEEE-754 infinity (`math.inf` is the cleaner spelling); `int("inf")` raises `ValueError`, and `int(float("inf"))` raises `OverflowError`. Common use: `min_val = float("inf")` as a running minimum tracker before a loop.

**Comparing floats** — never compare with `==` directly; binary floats are approximate (`0.1 + 0.2 != 0.3`).

```text
round(0.1 + 0.2, 2) == round(0.3, 2)  # True — quick check, but you must pick a precision
import math
math.isclose(0.1 + 0.2, 0.3)          # True — the standard-library answer, sensible default tolerance
from decimal import Decimal
Decimal('0.1') + Decimal('0.2') == Decimal('0.3')  # True — exact decimal arithmetic, use for money
```
