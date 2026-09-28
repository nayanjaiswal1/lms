---
kind: lesson
id_key: interview-prep-45/day-17
course: interview-prep-45
section: dsa
section_title: "Data Structures & Algorithms"
section_position: 2
title: "Backtracking: Constraint Satisfaction"
position: 20
estimated_minutes: 150
source:
    - 45-day-interview-roadmap.md
---

Think about seating guests at a wedding: each guest has a few people they can't sit next to, and every seat you fill changes which seats are still safe for everyone else. That's a constraint satisfaction problem, and it's the Backtracking lesson's template applied to problems where checking "is this choice valid" is itself the hard part. N-Queens needs fast conflict detection across three directions at once, Sudoku-style validation shows up in "design a checker" interviews, and IP address restoration tests whether you can bound a search with domain-specific rules instead of generic pruning. These are the backtracking problems that separate "knows the template" from "can adapt it."

## Constraint satisfaction

A constraint satisfaction problem (CSP) is a backtracking problem where "is this choice valid" depends on relationships between *multiple* previous choices, not just the most recent one. N-Queens is the classic example: placing a queen at `(row, col)` is invalid if any previously placed queen shares its column, or either diagonal.

The trick to making CSP backtracking fast is keeping validity-check information updated as you go, instead of re-scanning the whole board on every placement. A naive N-Queens checks every previously placed queen: O(n) per placement, O(n²) per row. A good one keeps three sets, columns, `row - col` diagonals, and `row + col` diagonals, for O(1) conflict checks.

```python
cols = set()
diag1 = set()   # row - col is constant along a "/" diagonal
diag2 = set()   # row + col is constant along a "\" diagonal

def is_safe(row: int, col: int) -> bool:
    return col not in cols and (row - col) not in diag1 and (row + col) not in diag2
```
```javascript +
const cols = new Set();
const diag1 = new Set();   // row - col is constant along a "/" diagonal
const diag2 = new Set();   // row + col is constant along a "\" diagonal

function isSafe(row, col) {
    return !cols.has(col) && !diag1.has(row - col) && !diag2.has(row + col);
}
```
```java +
import java.util.*;

public class Main {
    static Set<Integer> cols = new HashSet<>();
    static Set<Integer> diag1 = new HashSet<>();   // row - col is constant along a "/" diagonal
    static Set<Integer> diag2 = new HashSet<>();   // row + col is constant along a "\" diagonal

    public static boolean isSafe(int row, int col) {
        return !cols.contains(col) && !diag1.contains(row - col) && !diag2.contains(row + col);
    }

    public static void main(String[] args) {
        System.out.println(isSafe(0, 0));
        cols.add(0);
        diag1.add(0 - 0);
        diag2.add(0 + 0);
        System.out.println(isSafe(1, 1)); // false: same diagonal as (0,0)
    }
}
```

Why `row - col` and `row + col`: every cell on the same "/" diagonal shares the same `row - col` value; every cell on the same "\" diagonal shares the same `row + col` value. That one fact turns an O(n) check into O(1). Know it cold; it shows up in every N-Queens variant.

> **Remember:** a constraint satisfaction problem checks validity against everything placed so far, not just the last move. Precompute what you can into sets so each check stays O(1).

```knowledge-check
{ "questions": [
    { "id": "dsa-backtracking-adv-csp-q1", "type": "mcq",
      "prompt": "Why do row - col and row + col make useful set keys for N-Queens diagonal checks?",
      "options": [
        {"id": "a", "text": "Every cell on the same \"/\" diagonal shares the same row - col value, and every cell on the same \"\\\" diagonal shares the same row + col value"},
        {"id": "b", "text": "They're the only way to represent a 2D coordinate as a single number"},
        {"id": "c", "text": "row - col and row + col are always equal to each other"},
        {"id": "d", "text": "They only work when the board is exactly 8x8"}
      ],
      "correct": "a",
      "explanation": "Each diagonal is a line where one of those two expressions stays constant, so tracking them in a set gives an O(1) conflict check instead of scanning every placed queen." }
] }
```

## N-Queens pattern

The pattern: place one queen per row, which rules out row conflicts by construction, so you never need to check rows at all, try every column in that row, and recurse to the next row only if the placement is safe. Backtrack (remove the queen, unmark the sets) once a branch is exhausted.

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

This "one choice per slot" framing is worth generalizing: whenever a problem has a natural "one choice per slot, slots don't depend on each other's identity" structure, iterate over slots in the outer loop and choices in the inner loop. It collapses a 2D search space (which row, which column) into a 1D one (which column, since the row is implied by recursion depth).

> **Remember:** placing one item per row (or per slot) for free rules out a whole category of conflicts before you even start checking.

```knowledge-check
{ "questions": [
    { "id": "dsa-backtracking-adv-nqueens-q1", "type": "mcq",
      "prompt": "Why does the \"one queen per row\" placement strategy eliminate row conflicts entirely?",
      "options": [
        {"id": "a", "text": "Since exactly one queen is placed per row by construction, two queens can never share a row, so no row check is ever needed"},
        {"id": "b", "text": "Because rows are checked first before columns"},
        {"id": "c", "text": "Because the board is always square"},
        {"id": "d", "text": "It doesn't; row conflicts still need to be checked separately"}
      ],
      "correct": "a",
      "explanation": "The recursion advances row by row and places exactly one queen per row, so by the structure of the algorithm itself, no two queens ever land on the same row." }
] }
```

## Sudoku solving

Sudoku is N-Queens's constraint-satisfaction cousin with more rules: each number must be unique in its row, column, *and* 3x3 box. The backtracking shape is identical, try a value, recurse, undo, but the validity check now needs three conditions at once instead of one.

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
```javascript +
function isValid(board, row, col, num) {
    for (let i = 0; i < 9; i++) {
        if (board[row][i] === num || board[i][col] === num) return false;
    }
    const boxRow = 3 * Math.floor(row / 3);
    const boxCol = 3 * Math.floor(col / 3);
    for (let r = boxRow; r < boxRow + 3; r++) {
        for (let c = boxCol; c < boxCol + 3; c++) {
            if (board[r][c] === num) return false;
        }
    }
    return true;
}

function solveSudoku(board) {
    for (let row = 0; row < 9; row++) {
        for (let col = 0; col < 9; col++) {
            if (board[row][col] !== '.') continue;
            for (const num of '123456789') {
                if (isValid(board, row, col, num)) {
                    board[row][col] = num;
                    if (solveSudoku(board)) return true;
                    board[row][col] = '.'; // undo
                }
            }
            return false; // no valid number for this cell — dead end
        }
    }
    return true; // every cell filled
}
```
```java +
public class Main {
    public static boolean isValid(char[][] board, int row, int col, char num) {
        for (int i = 0; i < 9; i++) {
            if (board[row][i] == num || board[i][col] == num) return false;
        }
        int boxRow = 3 * (row / 3);
        int boxCol = 3 * (col / 3);
        for (int r = boxRow; r < boxRow + 3; r++) {
            for (int c = boxCol; c < boxCol + 3; c++) {
                if (board[r][c] == num) return false;
            }
        }
        return true;
    }

    public static boolean solveSudoku(char[][] board) {
        for (int row = 0; row < 9; row++) {
            for (int col = 0; col < 9; col++) {
                if (board[row][col] != '.') continue;
                for (char num = '1'; num <= '9'; num++) {
                    if (isValid(board, row, col, num)) {
                        board[row][col] = num;
                        if (solveSudoku(board)) return true;
                        board[row][col] = '.'; // undo
                    }
                }
                return false; // no valid number for this cell — dead end
            }
        }
        return true; // every cell filled
    }

    public static void main(String[] args) {
        char[][] board = {
            {'5','3','.','.','7','.','.','.','.'},
            {'6','.','.','1','9','5','.','.','.'},
            {'.','9','8','.','.','.','.','6','.'},
            {'8','.','.','.','6','.','.','.','3'},
            {'4','.','.','8','.','3','.','.','1'},
            {'7','.','.','.','2','.','.','.','6'},
            {'.','6','.','.','.','.','2','8','.'},
            {'.','.','.','4','1','9','.','.','5'},
            {'.','.','.','.','8','.','.','7','9'}
        };
        System.out.println(solveSudoku(board));
    }
}
```

The same lesson as N-Queens applies here: precomputing row/column/box "used number" sets instead of scanning turns each validity check into a true O(1) set lookup, instead of scanning 27 cells with fixed but wasteful constants. It's worth mentioning in an interview even if you don't have time to fully build it, since it shows you know exactly where the slow part would be.

> **Remember:** Sudoku is the same "try, recurse, undo" shape as N-Queens, just with three simultaneous constraints (row, column, box) instead of one.

```knowledge-check
{ "questions": [
    { "id": "dsa-backtracking-adv-sudoku-q1", "type": "mcq",
      "prompt": "What makes Sudoku's validity check harder than N-Queens', even though the backtracking shape is identical?",
      "options": [
        {"id": "a", "text": "Sudoku needs three simultaneous checks (row, column, and 3x3 box), while N-Queens only needs column and two diagonals"},
        {"id": "b", "text": "Sudoku doesn't use recursion at all"},
        {"id": "c", "text": "Sudoku has no undo step"},
        {"id": "d", "text": "Sudoku boards are always smaller than chessboards"}
      ],
      "correct": "a",
      "explanation": "Both problems try a value, recurse, and undo on failure. The difference is purely in how many conditions the validity check has to verify at once." }
] }
```

### N-Queens

[LeetCode 51 · N-Queens](https://leetcode.com/problems/n-queens/) · Backtracking · Hard

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
```javascript +
function solveNQueens(n) {
    const result = [];
    const colPositions = new Array(n).fill(0); // colPositions[row] = column of the queen in that row
    const cols = new Set(), diag1 = new Set(), diag2 = new Set();

    function backtrack(row) {
        if (row === n) {
            const board = [];
            for (let r = 0; r < n; r++) {
                const line = new Array(n).fill('.');
                line[colPositions[r]] = 'Q';
                board.push(line.join(''));
            }
            result.push(board);
            return;
        }
        for (let col = 0; col < n; col++) {
            if (cols.has(col) || diag1.has(row - col) || diag2.has(row + col)) continue;
            cols.add(col); diag1.add(row - col); diag2.add(row + col);
            colPositions[row] = col;
            backtrack(row + 1);
            cols.delete(col); diag1.delete(row - col); diag2.delete(row + col);
        }
    }

    backtrack(0);
    return result;
}
```
```java +
import java.util.*;

public class Main {
    public static List<List<String>> solveNQueens(int n) {
        List<List<String>> result = new ArrayList<>();
        int[] colPositions = new int[n]; // colPositions[row] = column of the queen in that row
        Set<Integer> cols = new HashSet<>(), diag1 = new HashSet<>(), diag2 = new HashSet<>();
        backtrack(0, n, colPositions, cols, diag1, diag2, result);
        return result;
    }

    private static void backtrack(int row, int n, int[] colPositions, Set<Integer> cols,
                                   Set<Integer> diag1, Set<Integer> diag2, List<List<String>> result) {
        if (row == n) {
            List<String> board = new ArrayList<>();
            for (int r = 0; r < n; r++) {
                char[] line = new char[n];
                Arrays.fill(line, '.');
                line[colPositions[r]] = 'Q';
                board.add(new String(line));
            }
            result.add(board);
            return;
        }
        for (int col = 0; col < n; col++) {
            if (cols.contains(col) || diag1.contains(row - col) || diag2.contains(row + col)) continue;
            cols.add(col); diag1.add(row - col); diag2.add(row + col);
            colPositions[row] = col;
            backtrack(row + 1, n, colPositions, cols, diag1, diag2, result);
            cols.remove(col); diag1.remove(row - col); diag2.remove(row + col);
        }
    }

    public static void main(String[] args) {
        System.out.println(solveNQueens(4));
    }
}
```

**Complexity:** O(n!) time worst case, roughly, since each row has fewer valid choices than the last thanks to pruning. O(n) space for the sets and recursion depth, excluding the output.

**Common mistakes:** using `row + col` and `row - col` backwards, or checking only one diagonal. Also, rebuilding the board string on every recursive call instead of only at `row == n`. And forgetting to remove from all three sets on backtrack, since a partial undo corrupts every sibling branch after the first.

> **Remember:** track columns and both diagonals as sets, place one queen per row, and undo all three sets when you backtrack, not just one.

### N-Queens II

[LeetCode 52 · N-Queens II](https://leetcode.com/problems/n-queens-ii/) · Backtracking · Count solutions

**Intuition:** The exact same search as N-Queens I, but you only need a count, not the actual board layouts. Drop the board-reconstruction step entirely and just increment a counter at `row == n`.

**Approach:** Same three-set conflict tracking; the recursion returns or accumulates an integer instead of appending to a results list.

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
```javascript +
function totalNQueens(n) {
    const cols = new Set(), diag1 = new Set(), diag2 = new Set();

    function backtrack(row) {
        if (row === n) return 1;
        let count = 0;
        for (let col = 0; col < n; col++) {
            if (cols.has(col) || diag1.has(row - col) || diag2.has(row + col)) continue;
            cols.add(col); diag1.add(row - col); diag2.add(row + col);
            count += backtrack(row + 1);
            cols.delete(col); diag1.delete(row - col); diag2.delete(row + col);
        }
        return count;
    }

    return backtrack(0);
}
```
```java +
import java.util.*;

public class Main {
    public static int totalNQueens(int n) {
        Set<Integer> cols = new HashSet<>(), diag1 = new HashSet<>(), diag2 = new HashSet<>();
        return backtrack(0, n, cols, diag1, diag2);
    }

    private static int backtrack(int row, int n, Set<Integer> cols, Set<Integer> diag1, Set<Integer> diag2) {
        if (row == n) return 1;
        int count = 0;
        for (int col = 0; col < n; col++) {
            if (cols.contains(col) || diag1.contains(row - col) || diag2.contains(row + col)) continue;
            cols.add(col); diag1.add(row - col); diag2.add(row + col);
            count += backtrack(row + 1, n, cols, diag1, diag2);
            cols.remove(col); diag1.remove(row - col); diag2.remove(row + col);
        }
        return count;
    }

    public static void main(String[] args) {
        System.out.println(totalNQueens(4));
    }
}
```

**Complexity:** Same as N-Queens I minus the O(n²) board-building cost per solution: O(n!) time worst case, O(n) space.

**Common mistakes:** building the full board anyway out of habit, wasting work when only a count is needed. Noticing "I don't need the reconstruction step at all" is itself an interview signal worth stating out loud.

> **Remember:** if the problem only asks "how many," don't build the thing you'd need to answer "which ones."

### Letter Combinations of a Phone Number

[LeetCode 17 · Letter Combinations of a Phone Number](https://leetcode.com/problems/letter-combinations-of-a-phone-number/) · Backtracking

**Intuition:** Each digit maps to a fixed set of letters, like an old T9 keypad. The output is the Cartesian product of every digit's letter set, and backtracking naturally lists a Cartesian product by looping over one dimension's options per recursion level.

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
```javascript +
function letterCombinations(digits) {
    if (!digits) return [];

    const mapping = {
        '2': 'abc', '3': 'def', '4': 'ghi', '5': 'jkl',
        '6': 'mno', '7': 'pqrs', '8': 'tuv', '9': 'wxyz',
    };
    const result = [];
    const path = [];

    function backtrack(index) {
        if (index === digits.length) {
            result.push(path.join(''));
            return;
        }
        for (const letter of mapping[digits[index]]) {
            path.push(letter);
            backtrack(index + 1);
            path.pop();
        }
    }

    backtrack(0);
    return result;
}
```
```java +
import java.util.*;

public class Main {
    public static List<String> letterCombinations(String digits) {
        List<String> result = new ArrayList<>();
        if (digits == null || digits.isEmpty()) return result;

        Map<Character, String> mapping = new HashMap<>();
        mapping.put('2', "abc"); mapping.put('3', "def"); mapping.put('4', "ghi");
        mapping.put('5', "jkl"); mapping.put('6', "mno"); mapping.put('7', "pqrs");
        mapping.put('8', "tuv"); mapping.put('9', "wxyz");

        backtrack(digits, 0, new StringBuilder(), mapping, result);
        return result;
    }

    private static void backtrack(String digits, int index, StringBuilder path,
                                   Map<Character, String> mapping, List<String> result) {
        if (index == digits.length()) {
            result.add(path.toString());
            return;
        }
        String letters = mapping.get(digits.charAt(index));
        for (char letter : letters.toCharArray()) {
            path.append(letter);
            backtrack(digits, index + 1, path, mapping, result);
            path.deleteCharAt(path.length() - 1);
        }
    }

    public static void main(String[] args) {
        System.out.println(letterCombinations("23"));
    }
}
```

**Complexity:** O(4^n * n) time worst case (digits 7 and 9 map to 4 letters, n is `len(digits)`), O(n) recursion depth.

**Common mistakes:** trying to solve this iteratively with nested loops for a variable number of digits. It works but is far messier than recursion, since the digit count isn't fixed. Also, forgetting the `if not digits: return []` edge case, since the expected answer is an empty list, not `[""]`.

> **Remember:** each digit contributes its own loop level. The whole output is the Cartesian product of all the digits' letter sets.

### Restore IP Addresses

[LeetCode 93 · Restore IP Addresses](https://leetcode.com/problems/restore-ip-addresses/) · Backtracking · Validation

**Intuition:** A valid IP address is 4 segments, each 1-3 digits, each in `[0, 255]`, with no leading zeros except the segment `"0"` itself. This is a partitioning problem: decide where to cut the string into 4 valid pieces.

**Approach:** Recurse on (remaining string, segments placed so far). At each step, try consuming 1, 2, or 3 characters as the next segment, validate, recurse. Prune early: if the remaining length can't possibly fill the remaining segments, since each segment is at most 3 characters, bail out.

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
```javascript +
function restoreIpAddresses(s) {
    const result = [];
    const path = [];

    function isValidSegment(seg) {
        if (seg.length > 1 && seg[0] === '0') return false; // no leading zeros
        return Number(seg) >= 0 && Number(seg) <= 255;
    }

    function backtrack(start) {
        if (path.length === 4) {
            if (start === s.length) result.push(path.join('.'));
            return;
        }
        const remainingSegments = 4 - path.length;
        const remainingChars = s.length - start;
        // prune: not enough or too many characters left for remaining segments
        if (remainingChars < remainingSegments || remainingChars > remainingSegments * 3) return;
        for (let length = 1; length <= 3; length++) {
            if (start + length > s.length) break;
            const segment = s.slice(start, start + length);
            if (!isValidSegment(segment)) continue;
            path.push(segment);
            backtrack(start + length);
            path.pop();
        }
    }

    backtrack(0);
    return result;
}
```
```java +
import java.util.*;

public class Main {
    public static List<String> restoreIpAddresses(String s) {
        List<String> result = new ArrayList<>();
        backtrack(s, 0, new ArrayDeque<>(), result);
        return result;
    }

    private static boolean isValidSegment(String seg) {
        if (seg.length() > 1 && seg.charAt(0) == '0') return false; // no leading zeros
        int value = Integer.parseInt(seg);
        return value >= 0 && value <= 255;
    }

    private static void backtrack(String s, int start, Deque<String> path, List<String> result) {
        if (path.size() == 4) {
            if (start == s.length()) result.add(String.join(".", path));
            return;
        }
        int remainingSegments = 4 - path.size();
        int remainingChars = s.length() - start;
        // prune: not enough or too many characters left for remaining segments
        if (remainingChars < remainingSegments || remainingChars > remainingSegments * 3) return;
        for (int length = 1; length <= 3; length++) {
            if (start + length > s.length()) break;
            String segment = s.substring(start, start + length);
            if (!isValidSegment(segment)) continue;
            path.addLast(segment);
            backtrack(s, start + length, path, result);
            path.removeLast();
        }
    }

    public static void main(String[] args) {
        System.out.println(restoreIpAddresses("25525511135"));
    }
}
```

**Complexity:** O(3^4) = O(1) effectively, since the search space is bounded by 4 segments times 3 possible lengths each, independent of input size beyond that small constant. O(1) extra space beyond output.

**Common mistakes:** forgetting the leading-zero rule (`"01"` is invalid even though `1 <= 255`). Also, skipping the remaining-length pruning, which wastes time exploring segment lengths that could never reach exactly 4 segments by the end of the string. And an off-by-one when slicing `s[start:start+length]`.

> **Remember:** four segments, each 1-3 characters, no leading zeros, each value 0-255. The pruning check before the loop keeps the search tiny.

N-Queens, Sudoku, and Restore IP Addresses look unrelated at first glance, but they're the same backtracking template wearing different validity checks: precomputed sets for N-Queens, three simultaneous scans for Sudoku, segment-length arithmetic for IP addresses. Once you see the validity check as a swappable piece, adapting the template to a new constraint satisfaction problem is mostly a matter of asking what "invalid" means here, and how cheaply you can detect it.
