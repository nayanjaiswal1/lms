---
kind: lesson
id_key: interview-prep-45/day-22
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Tries (Prefix Trees)"
position: 22
estimated_minutes: 120
source:
    - 45-day-interview-roadmap.md
---

A trie is a tree built for one job: prefix queries. Autocomplete, spell-check, IP routing tables, and word-search puzzles all reduce to "find everything that starts with this prefix," a job hash tables handle poorly. Today you build a trie from scratch, then use it in two escalating problems, one of them a classic hard.

## Trie node structure

Each node represents one character position and holds links to its children (one per possible next character) plus a flag marking "a word ends here."

```python
class TrieNode:
    def __init__(self):
        self.children = {}       # char -> TrieNode
        self.is_end_of_word = False
```

A path from the root spelling out `c-a-t` represents the string `"cat"`. Because nodes are shared across words with common prefixes, `"cat"` and `"car"` share the `c -> a` path and diverge only at the third character. That sharing is exactly what makes prefix queries cheap.

```
        root
        /
       c
       |
       a
      / \
     t   r
     *   *      (* marks is_end_of_word = True)
```

## Insert, search, prefix search

All three operations walk the tree one character at a time: O(m), where m is the word/prefix length. That cost is **independent of how many words are stored**.

```python
class Trie:
    def __init__(self):
        self.root = TrieNode()

    def insert(self, word: str) -> None:
        node = self.root
        for ch in word:
            if ch not in node.children:
                node.children[ch] = TrieNode()
            node = node.children[ch]
        node.is_end_of_word = True

    def _find_node(self, prefix: str):
        node = self.root
        for ch in prefix:
            if ch not in node.children:
                return None
            node = node.children[ch]
        return node

    def search(self, word: str) -> bool:
        node = self._find_node(word)
        return node is not None and node.is_end_of_word

    def startsWith(self, prefix: str) -> bool:
        return self._find_node(prefix) is not None
```

The distinction that trips people up: `search` requires `is_end_of_word == True` at the final node, meaning the exact word was inserted. `startsWith` only requires the path to exist: some word *starting with* this prefix was inserted, but the prefix itself might not be a complete word. Confusing these two is the most common trie bug.

## Space optimization

A naive trie node with a fixed 26-slot array (`children = [None] * 26`) wastes memory when the alphabet is small in practice or sparse in a given subtree. A dict (`children = {}`) only allocates entries for characters actually present, at the cost of slightly slower lookups: hashing instead of a direct array index.

| | Array of 26 | Dict |
|---|---|---|
| Lookup | O(1), direct index | O(1) average, hash overhead |
| Space per node | Fixed 26 slots always | Only used characters |
| Best for | Lowercase-only, dense tries | Unicode, sparse tries, unknown alphabet |

A further optimization for memory-constrained scenarios is the **compressed trie (radix tree)**: it merges chains of single-child nodes into one edge labeled with a substring instead of one character, which reduces node count dramatically for tries with many long unique suffixes. You're rarely asked to implement this in an interview, but it's worth naming if asked about scaling a trie to millions of entries.

## Implement Trie

[LeetCode 208](https://leetcode.com/problems/implement-trie-prefix-tree/) — Trie — Basic implementation

**Intuition:** Directly build the three-operation trie described above. This problem *is* the concept section's implementation, asked as a standalone exercise.

**Approach:** `TrieNode` holds a children dict and an end-of-word flag. `insert` walks or creates nodes as needed. `search` and `startsWith` walk and check existence, and `search` additionally checks the end-of-word flag.

```python
class Trie:
    def __init__(self):
        self.root = TrieNode()

    def insert(self, word: str) -> None:
        node = self.root
        for ch in word:
            node = node.children.setdefault(ch, TrieNode())
        node.is_end_of_word = True

    def search(self, word: str) -> bool:
        node = self.root
        for ch in word:
            if ch not in node.children:
                return False
            node = node.children[ch]
        return node.is_end_of_word

    def startsWith(self, prefix: str) -> bool:
        node = self.root
        for ch in prefix:
            if ch not in node.children:
                return False
            node = node.children[ch]
        return True
```

**Complexity:** `insert`/`search`/`startsWith` are all O(m) time, where m is the word/prefix length. Space O(total characters across all inserted words) in the worst case (no shared prefixes).

**Common mistakes:** Returning `True` from `search` just because the path exists, forgetting to check `is_end_of_word`. Also, using `node.children[ch] = TrieNode()` unconditionally on insert instead of checking first, which resets existing subtrees and loses previously inserted words.

## Word Search II

[LeetCode 212](https://leetcode.com/problems/word-search-ii/) — Trie + Backtracking — Hard

**Intuition:** Searching for each word in `words` independently via DFS on the board is O(words × board cells × 4^L), way too slow when both the word list and board are large. Instead, build one trie from all words, then do a **single DFS pass over the board**, walking the trie alongside the board path. This shares work across words with common prefixes and lets you prune a board path the instant it no longer matches *any* word's prefix.

**Approach:** Build a trie from `words` (mark word ends). DFS from every board cell; at each step, only continue if the current character exists as a trie child of the current trie node. When a trie node marks a complete word, record it (and mark the trie node visited/removed to avoid duplicate results). Backtrack the board cell after exploring.

```python
def findWords(board: list[list[str]], words: list[str]) -> list[str]:
    root = TrieNode()
    for word in words:
        node = root
        for ch in word:
            node = node.children.setdefault(ch, TrieNode())
        node.is_end_of_word = True
        node.word = word  # stash the full word at the terminal node

    rows, cols = len(board), len(board[0])
    result = []

    def dfs(r, c, node):
        ch = board[r][c]
        if ch not in node.children:
            return
        nxt = node.children[ch]
        if nxt.is_end_of_word:
            result.append(nxt.word)
            nxt.is_end_of_word = False  # avoid duplicate matches

        board[r][c] = '#'  # mark visited in place
        for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nr, nc = r + dr, c + dc
            if 0 <= nr < rows and 0 <= nc < cols and board[nr][nc] != '#':
                dfs(nr, nc, nxt)
        board[r][c] = ch  # backtrack

        if not nxt.children:  # prune dead trie branches for efficiency
            node.children.pop(ch)

    for r in range(rows):
        for c in range(cols):
            dfs(r, c, root)

    return result
```

**Complexity:** Time O(rows × cols × 4^L) in the worst case (L = longest word length), but the trie pruning, stopping as soon as no word's prefix matches and removing exhausted branches, makes it far faster in practice than per-word DFS. Space O(total trie nodes + recursion depth).

**Common mistakes:** Running separate DFS searches per word instead of one shared trie-guided DFS is correct but too slow for the hard-tier constraints. Forgetting to backtrack the board mutation (`board[r][c] = ch` after recursion) corrupts later searches. And skipping the guard against duplicate results, needed when the same word could be found via multiple paths: the `is_end_of_word = False` reset after first match handles this.

## Replace Words

[LeetCode 648](https://leetcode.com/problems/replace-words/) — Trie

**Intuition:** For each word in a sentence, find its *shortest* dictionary root, if any, and replace the word with that root. A trie built from the roots lets you walk each word character by character and stop at the first `is_end_of_word` you hit, which is automatically the shortest matching root.

**Approach:** Insert all roots into a trie. For each word in the sentence, walk the trie; if you hit `is_end_of_word` before running out of characters (or the trie path), replace the word with the prefix walked so far. Otherwise keep the original word.

```python
def replaceWords(dictionary: list[str], sentence: str) -> str:
    root_trie = TrieNode()
    for root in dictionary:
        node = root_trie
        for ch in root:
            node = node.children.setdefault(ch, TrieNode())
        node.is_end_of_word = True

    def find_root(word: str) -> str:
        node = root_trie
        prefix = []
        for ch in word:
            if ch not in node.children:
                return word  # no matching root, keep original
            prefix.append(ch)
            node = node.children[ch]
            if node.is_end_of_word:
                return "".join(prefix)
        return word

    return " ".join(find_root(word) for word in sentence.split())
```

**Complexity:** Time O(total characters in dictionary + total characters in sentence), space O(total characters in dictionary) for the trie.

**Common mistakes:** Not stopping at the *first* `is_end_of_word` encountered. The problem wants the shortest matching root, and continuing past it would incorrectly look for a longer one. Also, using a naive "try every root as a prefix with `str.startswith`" approach, which is O(words × roots × root_length) instead of the trie's near-linear scan.

## Maximum XOR of Two Numbers in an Array

[LeetCode 421](https://leetcode.com/problems/maximum-xor-of-two-numbers-in-an-array/) — Trie — Hard

**Intuition:** To maximize XOR of two numbers, you want their bits to differ at the most significant positions possible. A **binary trie**, where each node has at most 2 children (bit 0 or bit 1), lets you, for each number, greedily walk toward the *opposite* bit at every position. That greedy walk finds the best XOR partner for that number in O(32) instead of comparing against every other number. It's the same prefix-tree idea from earlier in the lesson, just applied to bits instead of characters.

**Approach:** Insert every number into a binary trie, most-significant-bit first (fixed 32-bit width). For each number, walk the trie trying to go the opposite direction of each of its bits; when the opposite branch doesn't exist, take the only available branch. Track the best XOR found.

```python
class BinaryTrieNode:
    def __init__(self):
        self.children = {}  # 0 or 1 -> BinaryTrieNode

def findMaximumXOR(nums: list[int]) -> int:
    root = BinaryTrieNode()
    BITS = 31  # enough for LeetCode's constraint (nums < 2^31)

    def insert(num):
        node = root
        for i in range(BITS, -1, -1):
            bit = (num >> i) & 1
            node = node.children.setdefault(bit, BinaryTrieNode())

    def query(num):
        node = root
        xor = 0
        for i in range(BITS, -1, -1):
            bit = (num >> i) & 1
            desired = 1 - bit  # the opposite bit maximizes this position's contribution
            if desired in node.children:
                xor |= (1 << i)
                node = node.children[desired]
            else:
                node = node.children[bit]
        return xor

    for num in nums:
        insert(num)

    return max(query(num) for num in nums)
```

**Complexity:** Time O(n × 32) = O(n), space O(n × 32) for the trie nodes. Far better than the naive O(n²) pairwise XOR comparison.

**Common mistakes:** Iterating bits least-significant-first instead of most-significant-first. The greedy "prefer the opposite bit" strategy only produces the maximum XOR when higher bit positions are decided before lower ones. Also, forgetting a fixed bit width, which causes negative numbers or inconsistent trie depths to break comparisons.
