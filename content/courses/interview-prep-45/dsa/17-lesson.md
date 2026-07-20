---
kind: lesson
id_key: interview-prep-45/day-17
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Day 17 — Backtracking - Advanced"
position: 17
estimated_minutes: 150
source:
    - 45-day-interview-roadmap.md
---
Yesterday was the backtracking template. Today is applying it to problems where the constraint-checking itself is the hard part — N-Queens needs efficient conflict detection across three directions at once, Sudoku-style constraint satisfaction shows up in "design a validator" interviews, and IP address restoration tests whether you can bound a search space with domain-specific rules instead of generic pruning. These are the backtracking problems that separate "knows the template" from "can adapt it."

## Constraint satisfaction

A constraint satisfaction problem (CSP) is a backtracking problem where the "is this choice valid" check depends on relationships between *multiple* previous choices, not just the most recent one. N-Queens is the canonical example: placing a queen at `(row, col)` is invalid if any previously placed queen shares its column, or either diagonal.

The trick to making CSP backtracking efficient is maintaining validity-check state incrementally instead of re-scanning the whole board on every placement. A naive N-Queens checks all previously placed queens (O(n) per placement, O(n^2) per row) — a good one uses three sets (columns, `row - col` diagonals, `row + col` diagonals) for O(1) conflict checks.

```python
cols = set()
diag1 = set()   # row - col is constant along a "/" diagonal
diag2 = set()   # row + col is constant along a "\" diagonal

def is_safe(row: int, col: int) -> bool:
    return col not in cols and (row - col) not in diag1 and (row + col) not in diag2
```

Why `row - col` and `row + col`: every cell on the same "/" diagonal has the same `row - col` value; every cell on the same "\" diagonal has the same `row + col` value. This is the piece of domain knowledge that turns an O(n) check into O(1) — know it cold, it comes up in every N-Queens variant.

## N-Queens pattern

The pattern: place one queen per row (this eliminates row conflicts by construction — you never need to check rows), try every column in that row, and recurse to the next row only if the placement is safe. Backtrack (remove the queen, unmark the sets) when a branch is exhausted.

```python
def solve(row: int) -> None:
    if row == n:
        record_solution()
        return
    for col in range(n):
        if not is_safe(row, col):
            continue
        place(row, col)
        solve(row + 1)
        remove(row, col)
```

This "one queen per row" framing is worth generalizing: whenever a problem has a natural "one choice per slot, slots are independent of each other's identity" structure, iterate over slots in the outer loop and choices in the inner loop — it collapses a 2D search space (which row, which column) into a 1D one (which column, since row is implied by recursion depth).

## Sudoku solving

Sudoku is N-Queens's constraint-satisfaction cousin with more constraint types: each number must be unique in its row, column, *and* 3x3 box. The backtracking shape is identical (try a value, recurse, undo) — what changes is the validity check needs three simultaneous conditions instead of one.

```python
def is_valid(board, row: int, col: int, num: str) -> bool:
    for i in range(9):
        if board[row][i] == num or board[i][col] == num:
            return False
    box_row, box_col = 3 * (row // 3), 3 * (col // 3)
    for r in range(box_row, box_row + 3):
        for c in range(box_col, box_col + 3):
            if board[r][c] == num:
                return False
    return True

def solve_sudoku(board: list[list[str]]) -> bool:
    for row in range(9):
        for col in range(9):
            if board[row][col] != '.':
                continue
            for num in '123456789':
                if is_valid(board, row, col, num):
                    board[row][col] = num
                    if solve_sudoku(board):
                        return True
                    board[row][col] = '.'   # undo
            return False   # no valid number for this cell — dead end
    return True   # every cell filled
```

Same lesson as N-Queens: precomputing row/col/box "used number" sets instead of scanning turns each validity check from O(1) with fixed small constants (27 cells) into truly O(1) set lookups — worth mentioning in an interview even if you don't have time to fully implement it, since it shows you know where the bottleneck is.

### N-Queens

[LeetCode 51 — N-Queens](https://leetcode.com/problems/n-queens/) — Backtracking — Hard

**Intuition:** Place queens row by row; a row can never conflict with itself, so the only checks needed are column and both diagonals against previously placed queens.

**Approach:** Track `cols`, `diag1` (`row - col`), `diag2` (`row + col`) as sets for O(1) conflict checks. Recurse row by row; when `row == n`, convert the current column choices into the board string format and record.

```python
def solve_n_queens(n: int) -> list[list[str]]:
    result = []
    col_positions = [0] * n   # col_positions[row] = column of the queen in that row
    cols, diag1, diag2 = set(), set(), set()

    def backtrack(row: int) -> None:
        if row == n:
            board = []
            for r in range(n):
                line = ['.'] * n
                line[col_positions[r]] = 'Q'
                board.append(''.join(line))
            result.append(board)
            return
        for col in range(n):
            if col in cols or (row - col) in diag1 or (row + col) in diag2:
                continue
            cols.add(col); diag1.add(row - col); diag2.add(row + col)
            col_positions[row] = col
            backtrack(row + 1)
            cols.remove(col); diag1.remove(row - col); diag2.remove(row + col)

    backtrack(0)
    return result
```

**Complexity:** O(n!) time worst case (roughly — each row has fewer valid choices than the last due to pruning), O(n) space for the sets and recursion depth, excluding output.

**Common mistakes:** using `row + col` and `row - col` backwards or checking only one diagonal; rebuilding the board string on every recursive call instead of only at `row == n`; forgetting to remove from all three sets on backtrack (a partial undo corrupts every sibling branch after the first).

### N-Queens II

[LeetCode 52 — N-Queens II](https://leetcode.com/problems/n-queens-ii/) — Backtracking — Count solutions

**Intuition:** Identical search to N-Queens I, but you only need a count, not the actual board layouts — drop the board-reconstruction entirely and just increment a counter at `row == n`.

**Approach:** Same three-set conflict tracking; recursion returns/accumulates an integer instead of appending to a results list.

```python
def total_n_queens(n: int) -> int:
    cols, diag1, diag2 = set(), set(), set()

    def backtrack(row: int) -> int:
        if row == n:
            return 1
        count = 0
        for col in range(n):
            if col in cols or (row - col) in diag1 or (row + col) in diag2:
                continue
            cols.add(col); diag1.add(row - col); diag2.add(row + col)
            count += backtrack(row + 1)
            cols.remove(col); diag1.remove(row - col); diag2.remove(row + col)
        return count

    return backtrack(0)
```

**Complexity:** Same as N-Queens I minus the O(n^2) board-building cost per solution — O(n!) time worst case, O(n) space.

**Common mistakes:** building the full board anyway out of habit (wasted work when only a count is needed) — recognizing "I don't need the reconstruction step" is itself an interview signal.

### Letter Combinations of a Phone Number

[LeetCode 17 — Letter Combinations of a Phone Number](https://leetcode.com/problems/letter-combinations-of-a-phone-number/) — Backtracking

**Intuition:** Each digit maps to a fixed set of letters (like an old T9 keypad). The output is the Cartesian product of each digit's letter set — backtracking naturally enumerates a Cartesian product by looping over one dimension's options per recursion level.

**Approach:** Recurse by digit index; at each level, loop over that digit's mapped letters, append, recurse to the next digit, undo.

```python
def letter_combinations(digits: str) -> list[str]:
    if not digits:
        return []

    mapping = {
        '2': 'abc', '3': 'def', '4': 'ghi', '5': 'jkl',
        '6': 'mno', '7': 'pqrs', '8': 'tuv', '9': 'wxyz',
    }
    result = []
    path = []

    def backtrack(index: int) -> None:
        if index == len(digits):
            result.append(''.join(path))
            return
        for letter in mapping[digits[index]]:
            path.append(letter)
            backtrack(index + 1)
            path.pop()

    backtrack(0)
    return result
```

**Complexity:** O(4^n * n) time worst case (digits 7 and 9 map to 4 letters, n is `len(digits)`), O(n) recursion depth.

**Common mistakes:** trying to solve this iteratively with nested loops for a variable number of digits (works but is far messier than recursion since digit count isn't fixed); forgetting the `if not digits: return []` edge case — LeetCode expects an empty list, not `[""]`.

### Restore IP Addresses

[LeetCode 93 — Restore IP Addresses](https://leetcode.com/problems/restore-ip-addresses/) — Backtracking — Validation

**Intuition:** A valid IP address is 4 segments, each 1-3 digits, each in `[0, 255]`, with no leading zeros (except the segment `"0"` itself). This is a partitioning problem — decide where to cut the string into 4 valid pieces.

**Approach:** Recurse on (remaining string, segments placed so far). At each step, try consuming 1, 2, or 3 characters as the next segment, validate, recurse. Prune early: if remaining length can't possibly fill the remaining segments (each segment is at most 3 chars), bail out.

```python
def restore_ip_addresses(s: str) -> list[str]:
    result = []
    path = []

    def is_valid_segment(seg: str) -> bool:
        if len(seg) > 1 and seg[0] == '0':   # no leading zeros
            return False
        return 0 <= int(seg) <= 255

    def backtrack(start: int) -> None:
        if len(path) == 4:
            if start == len(s):
                result.append('.'.join(path))
            return
        remaining_segments = 4 - len(path)
        remaining_chars = len(s) - start
        # prune: not enough or too many characters left for remaining segments
        if not (remaining_segments <= remaining_chars <= remaining_segments * 3):
            return
        for length in range(1, 4):
            if start + length > len(s):
                break
            segment = s[start:start + length]
            if not is_valid_segment(segment):
                continue
            path.append(segment)
            backtrack(start + length)
            path.pop()

    backtrack(0)
    return result
```

**Complexity:** O(3^4) = O(1) effectively — the search space is bounded by 4 segments x 3 possible lengths each, independent of input size beyond a small constant. O(1) extra space beyond output.

**Common mistakes:** forgetting the leading-zero rule (`"01"` is invalid even though `1 <= 255`); not pruning on remaining-length bounds, which wastes time exploring segment lengths that can't possibly reach exactly 4 segments by the end of the string; off-by-one when slicing `s[start:start+length]`.

## Key takeaways

- CSP backtracking (N-Queens, Sudoku) needs O(1) conflict checks via precomputed sets, not O(n) rescans — `row - col` / `row + col` is the diagonal trick to memorize.
- "One choice per slot" problems (queens per row, phone digits) collapse a multi-dimensional search into recursion depth = slot index, loop = choice within that slot.
- N-Queens II shows that sometimes you can drop expensive reconstruction work (building the board) when only a count is needed — always ask what the output actually requires.
- Restore IP Addresses is backtracking with domain-specific validation and pruning (leading zeros, segment length bounds) rather than generic "avoid duplicates" pruning.
- Prune using bounds on remaining work (`remaining_segments <= remaining_chars <= remaining_segments * 3`) whenever the problem gives you a fixed target shape.
- Undo state fully and in the same order it was added — partial undos are the most common bug in CSP backtracking.

## Today's checklist

- [ ] Solve N-Queens (LeetCode 51)
- [ ] Solve N-Queens II (LeetCode 52)
- [ ] Solve Letter Combinations of a Phone Number (LeetCode 17)
- [ ] Solve Restore IP Addresses (LeetCode 93)
- [ ] Implement N-Queens with position validation using the three-set trick
- [ ] Practice pruning invalid states as early as possible
- [ ] Memorize: N-Queens uses 3 sets for column/diagonal constraints
- [ ] Review how to convert a new problem into the backtracking template
