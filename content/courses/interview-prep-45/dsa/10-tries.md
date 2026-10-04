---
kind: lesson
id_key: interview-prep-45/day-22
course: interview-prep-45
section: dsa
section_title: "Data Structures & Algorithms"
section_position: 2
title: "Tries (Prefix Trees)"
position: 10
estimated_minutes: 120
source:
    - 45-day-interview-roadmap.md
---
Type "ca" into your phone's contacts search and it instantly shows "Carl," "Carol," and "Cathy." That's a trie at work: a tree built for exactly one job, answering "what starts with this prefix?" Autocomplete, spell-check, IP routing tables, and word-search puzzles all reduce to that same question, one a hash table answers poorly since it can only match whole keys, not prefixes. This lesson builds a trie from scratch, then uses it on two escalating problems, one of them a hard.

## What a trie node holds

Each node represents one character position. It holds links to its children, one per possible next character, plus a flag marking "a word ends here."

```python
class TrieNode:
    def __init__(self):
        self.children = {}       # char -> TrieNode
        self.is_end_of_word = False
```

```javascript +
class TrieNode {
    constructor() {
        this.children = new Map(); // char -> TrieNode
        this.isEndOfWord = false;
    }
}
```

```java +
import java.util.HashMap;
import java.util.Map;

public class Main {
    public static void main(String[] args) {
        TrieNode node = new TrieNode();
        System.out.println(node.isEndOfWord);
    }
}

class TrieNode {
    Map<Character, TrieNode> children = new HashMap<>(); // char -> TrieNode
    boolean isEndOfWord = false;
}
```

A path from the root spelling `c-a-t` represents the word `"cat"`. Words that share a prefix share nodes: `"cat"` and `"car"` both walk `c -> a`, then split at the third letter. That sharing is exactly what makes prefix queries cheap; you're not comparing "cat" against "car" character by character, you're walking one shared path and branching only where the words actually differ.

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

> **Remember:** a trie node is a character position, not a whole word. Shared prefixes share the same nodes.

```knowledge-check
{ "questions": [
    { "id": "dsa-tries-node-structure-q1", "type": "mcq",
      "prompt": "In a trie storing both 'cat' and 'car', at which point do the two words stop sharing nodes?",
      "options": [
        {"id": "a", "text": "After 'ca', where the paths split into 't' and 'r'"},
        {"id": "b", "text": "They never share any nodes"},
        {"id": "c", "text": "Only the root is shared"},
        {"id": "d", "text": "They share every node, including the final one"}
      ],
      "correct": "a",
      "explanation": "Both words start c -> a, walking the same two nodes. They diverge only at the third character, where one path goes to 't' and the other to 'r'." }
] }
```

## Insert, search, and prefix search

All three operations walk the tree one character at a time: O(m), where m is the length of the word or prefix. That cost never depends on how many other words are already stored, only on the length of what you're looking up.

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

```javascript +
class TrieNode {
    constructor() {
        this.children = new Map(); // char -> TrieNode
        this.isEndOfWord = false;
    }
}

class Trie {
    constructor() {
        this.root = new TrieNode();
    }

    insert(word) {
        let node = this.root;
        for (const ch of word) {
            if (!node.children.has(ch)) {
                node.children.set(ch, new TrieNode());
            }
            node = node.children.get(ch);
        }
        node.isEndOfWord = true;
    }

    _findNode(prefix) {
        let node = this.root;
        for (const ch of prefix) {
            if (!node.children.has(ch)) {
                return null;
            }
            node = node.children.get(ch);
        }
        return node;
    }

    search(word) {
        const node = this._findNode(word);
        return node !== null && node.isEndOfWord;
    }

    startsWith(prefix) {
        return this._findNode(prefix) !== null;
    }
}
```

```java +
import java.util.HashMap;
import java.util.Map;

public class Main {
    public static void main(String[] args) {
        Trie trie = new Trie();
        trie.insert("cat");
        System.out.println(trie.search("cat"));
        System.out.println(trie.startsWith("ca"));
    }
}

class TrieNode {
    Map<Character, TrieNode> children = new HashMap<>(); // char -> TrieNode
    boolean isEndOfWord = false;
}

class Trie {
    TrieNode root = new TrieNode();

    void insert(String word) {
        TrieNode node = root;
        for (char ch : word.toCharArray()) {
            node = node.children.computeIfAbsent(ch, c -> new TrieNode());
        }
        node.isEndOfWord = true;
    }

    private TrieNode findNode(String prefix) {
        TrieNode node = root;
        for (char ch : prefix.toCharArray()) {
            if (!node.children.containsKey(ch)) {
                return null;
            }
            node = node.children.get(ch);
        }
        return node;
    }

    boolean search(String word) {
        TrieNode node = findNode(word);
        return node != null && node.isEndOfWord;
    }

    boolean startsWith(String prefix) {
        return findNode(prefix) != null;
    }
}
```

The detail that trips people up: `search` needs `is_end_of_word == True` at the final node, meaning the exact word was inserted. `startsWith` only needs the path to exist; some word *starting with* this prefix was inserted, but the prefix itself might not be a whole word on its own. Mixing these two up is the most common trie bug.

> **Remember:** `search` needs the path AND the end-of-word flag. `startsWith` needs only the path.

```knowledge-check
{ "questions": [
    { "id": "dsa-tries-insert-search-q1", "type": "mcq",
      "prompt": "After inserting only the word 'card' into a trie, what does startsWith('car') return, and why?",
      "options": [
        {"id": "a", "text": "True, because the path c-a-r exists, even though 'car' itself was never inserted as a full word"},
        {"id": "b", "text": "False, because 'car' was never inserted as its own word"},
        {"id": "c", "text": "True only if is_end_of_word is set on the 'r' node"},
        {"id": "d", "text": "It throws an error since 'car' is not a complete word"}
      ],
      "correct": "a",
      "explanation": "startsWith only checks that the path exists in the trie, not that a word ends there. Since 'card' was inserted, the path c-a-r exists as a prefix of it, so startsWith('car') is true regardless of the end-of-word flag." }
] }
```

## Trading memory for speed

A naive trie node using a fixed 26-slot array (`children = [None] * 26`) wastes memory whenever the alphabet in a given subtree is small or sparse. A dict-based node (`children = {}`) only allocates entries for characters actually present, at the cost of slightly slower lookups: hashing instead of a direct array index.

| | Array of 26 | Dict |
|---|---|---|
| Lookup | O(1), direct index | O(1) average, hash overhead |
| Space per node | Fixed 26 slots always | Only used characters |
| Best for | Lowercase-only, dense tries | Unicode, sparse tries, unknown alphabet |

A further optimization for memory-constrained cases is the **compressed trie (radix tree)**: it merges chains of single-child nodes into one edge labeled with a substring instead of one character, cutting node count sharply for tries with many long, unique suffixes. You're rarely asked to implement this in an interview, but naming it is worth doing if asked how you'd scale a trie to millions of entries.

> **Remember:** array children are faster but always cost 26 slots; dict children only pay for characters actually used.

```knowledge-check
{ "questions": [
    { "id": "dsa-tries-space-optimization-q1", "type": "mcq",
      "prompt": "When is a dict-based trie node a better choice than a fixed 26-slot array?",
      "options": [
        {"id": "a", "text": "When the alphabet is large or sparse, such as Unicode text, so you don't allocate unused slots"},
        {"id": "b", "text": "Always, since dicts are faster in every case"},
        {"id": "c", "text": "Never, arrays are always better for tries"},
        {"id": "d", "text": "Only when the trie has fewer than 26 words"}
      ],
      "correct": "a",
      "explanation": "An array always reserves 26 slots per node even if only one child is used. A dict only pays for characters actually present, which wins when the alphabet is large or most nodes are sparse." }
] }
```

## Implement Trie

[LeetCode 208](https://leetcode.com/problems/implement-trie-prefix-tree/) — Trie — Basic implementation

This problem is the concept section above, asked as a standalone exercise: build `insert`, `search`, and `startsWith` directly.

**Approach:** `TrieNode` holds a children dict and an end-of-word flag. `insert` walks or creates nodes as needed. `search` and `startsWith` walk and check existence; `search` additionally checks the end-of-word flag.

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

```javascript +
class TrieNode {
    constructor() {
        this.children = new Map();
        this.isEndOfWord = false;
    }
}

class Trie {
    constructor() {
        this.root = new TrieNode();
    }

    insert(word) {
        let node = this.root;
        for (const ch of word) {
            if (!node.children.has(ch)) {
                node.children.set(ch, new TrieNode());
            }
            node = node.children.get(ch);
        }
        node.isEndOfWord = true;
    }

    search(word) {
        let node = this.root;
        for (const ch of word) {
            if (!node.children.has(ch)) {
                return false;
            }
            node = node.children.get(ch);
        }
        return node.isEndOfWord;
    }

    startsWith(prefix) {
        let node = this.root;
        for (const ch of prefix) {
            if (!node.children.has(ch)) {
                return false;
            }
            node = node.children.get(ch);
        }
        return true;
    }
}
```

```java +
import java.util.HashMap;
import java.util.Map;

public class Main {
    public static void main(String[] args) {
        Trie trie = new Trie();
        trie.insert("apple");
        System.out.println(trie.search("apple"));
        System.out.println(trie.search("app"));
        System.out.println(trie.startsWith("app"));
    }
}

class TrieNode {
    Map<Character, TrieNode> children = new HashMap<>();
    boolean isEndOfWord = false;
}

class Trie {
    TrieNode root = new TrieNode();

    void insert(String word) {
        TrieNode node = root;
        for (char ch : word.toCharArray()) {
            node = node.children.computeIfAbsent(ch, c -> new TrieNode());
        }
        node.isEndOfWord = true;
    }

    boolean search(String word) {
        TrieNode node = root;
        for (char ch : word.toCharArray()) {
            if (!node.children.containsKey(ch)) {
                return false;
            }
            node = node.children.get(ch);
        }
        return node.isEndOfWord;
    }

    boolean startsWith(String prefix) {
        TrieNode node = root;
        for (char ch : prefix.toCharArray()) {
            if (!node.children.containsKey(ch)) {
                return false;
            }
            node = node.children.get(ch);
        }
        return true;
    }
}
```

**Complexity:** `insert`/`search`/`startsWith` are all O(m) time, where m is the word or prefix length. Space O(total characters across all inserted words) in the worst case, when no prefixes are shared.

**Common mistakes:** Returning `True` from `search` just because the path exists, forgetting the end-of-word check. Also, unconditionally writing `node.children[ch] = TrieNode()` on insert instead of checking first, which wipes out existing subtrees and loses previously inserted words.

> **Remember:** this problem IS the concept section. If you can write insert/search/startsWith from memory, you know tries.

```knowledge-check
{ "questions": [
    { "id": "dsa-tries-implement-trie-q1", "type": "mcq",
      "prompt": "What bug happens if insert always does `node.children[ch] = TrieNode()` instead of checking if the child already exists?",
      "options": [
        {"id": "a", "text": "It overwrites an existing subtree, losing every word previously stored below that point"},
        {"id": "b", "text": "Nothing, the trie still works correctly"},
        {"id": "c", "text": "It makes search run in O(n) instead of O(m)"},
        {"id": "d", "text": "It causes an infinite loop"}
      ],
      "correct": "a",
      "explanation": "Overwriting the child node discards any words that were already stored in that subtree. Insert must reuse an existing child if one is there, only creating a new node when the character path doesn't exist yet." }
] }
```

## Word Search II

[LeetCode 212](https://leetcode.com/problems/word-search-ii/) — Trie + Backtracking — Hard

Searching the board separately for each word in a word list, one full DFS per word, is far too slow when both the board and the word list are large. Instead, build one trie from every word, then run a single DFS pass over the board, walking the trie and the board together, step for step. This shares work across words with common prefixes and lets you prune a board path the instant it stops matching *any* word's prefix.

**Approach:** Build a trie from `words` (mark word ends). DFS from every board cell; at each step, only continue if the current character exists as a trie child of the current trie node. When a trie node marks a complete word, record it (and mark that trie node as spent, to avoid duplicate results). Backtrack the board cell after exploring.

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

```javascript +
class TrieNode {
    constructor() {
        this.children = new Map();
        this.isEndOfWord = false;
        this.word = null;
    }
}

function findWords(board, words) {
    const root = new TrieNode();
    for (const word of words) {
        let node = root;
        for (const ch of word) {
            if (!node.children.has(ch)) {
                node.children.set(ch, new TrieNode());
            }
            node = node.children.get(ch);
        }
        node.isEndOfWord = true;
        node.word = word; // stash the full word at the terminal node
    }

    const rows = board.length;
    const cols = board[0].length;
    const result = [];

    function dfs(r, c, node) {
        const ch = board[r][c];
        if (!node.children.has(ch)) return;
        const nxt = node.children.get(ch);
        if (nxt.isEndOfWord) {
            result.push(nxt.word);
            nxt.isEndOfWord = false; // avoid duplicate matches
        }

        board[r][c] = '#'; // mark visited in place
        for (const [dr, dc] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
            const nr = r + dr;
            const nc = c + dc;
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && board[nr][nc] !== '#') {
                dfs(nr, nc, nxt);
            }
        }
        board[r][c] = ch; // backtrack

        if (nxt.children.size === 0) { // prune dead trie branches for efficiency
            node.children.delete(ch);
        }
    }

    for (let r = 0; r < rows; r++) {
        for (let c = 0; c < cols; c++) {
            dfs(r, c, root);
        }
    }

    return result;
}
```

```java +
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class Main {
    public static void main(String[] args) {
        char[][] board = {
            {'o', 'a', 'a', 'n'},
            {'e', 't', 'a', 'e'},
            {'i', 'h', 'k', 'r'},
            {'i', 'f', 'l', 'v'}
        };
        String[] words = {"oath", "pea", "eat", "rain"};
        System.out.println(findWords(board, words));
    }

    static int rows, cols;
    static char[][] board;
    static List<String> result;

    static List<String> findWords(char[][] inputBoard, String[] words) {
        board = inputBoard;
        TrieNode root = new TrieNode();
        for (String word : words) {
            TrieNode node = root;
            for (char ch : word.toCharArray()) {
                node = node.children.computeIfAbsent(ch, c -> new TrieNode());
            }
            node.isEndOfWord = true;
            node.word = word; // stash the full word at the terminal node
        }

        rows = board.length;
        cols = board[0].length;
        result = new ArrayList<>();

        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                dfs(r, c, root);
            }
        }

        return result;
    }

    static void dfs(int r, int c, TrieNode node) {
        char ch = board[r][c];
        if (!node.children.containsKey(ch)) return;
        TrieNode nxt = node.children.get(ch);
        if (nxt.isEndOfWord) {
            result.add(nxt.word);
            nxt.isEndOfWord = false; // avoid duplicate matches
        }

        board[r][c] = '#'; // mark visited in place
        int[][] dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};
        for (int[] dir : dirs) {
            int nr = r + dir[0], nc = c + dir[1];
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && board[nr][nc] != '#') {
                dfs(nr, nc, nxt);
            }
        }
        board[r][c] = ch; // backtrack

        if (nxt.children.isEmpty()) { // prune dead trie branches for efficiency
            node.children.remove(ch);
        }
    }
}

class TrieNode {
    Map<Character, TrieNode> children = new HashMap<>();
    boolean isEndOfWord = false;
    String word;
}
```

**Complexity:** Time O(rows × cols × 4^L) in the worst case (L = longest word length), but trie pruning, stopping as soon as no word's prefix matches and removing exhausted branches, makes it far faster in practice than a per-word DFS. Space O(total trie nodes + recursion depth).

**Common mistakes:** Running a separate DFS search per word instead of one shared trie-guided DFS. Correct, but too slow for the hard-tier constraints. Forgetting to backtrack the board mutation after recursion, which corrupts later searches. Skipping the guard against duplicate results when the same word can be found via multiple paths; resetting the end-of-word flag after the first match handles this.

> **Remember:** one trie built from all words, one shared DFS over the board, pruning dead branches as you go.

```knowledge-check
{ "questions": [
    { "id": "dsa-tries-word-search-ii-q1", "type": "mcq",
      "prompt": "Why build one trie from all target words instead of running a separate DFS search for each word?",
      "options": [
        {"id": "a", "text": "A shared trie lets one DFS pass share work across words with common prefixes and prune paths early"},
        {"id": "b", "text": "A trie is required for DFS to work on a grid at all"},
        {"id": "c", "text": "It reduces the answer's correctness requirements"},
        {"id": "d", "text": "It only matters when the board has fewer than 4 cells"}
      ],
      "correct": "a",
      "explanation": "Separate per-word DFS repeats work for every word independently. A shared trie lets one DFS walk match multiple words' prefixes at once, and stop exploring the moment no word's prefix matches anymore." }
] }
```

## Replace Words

[LeetCode 648](https://leetcode.com/problems/replace-words/) — Trie

For each word in a sentence, find its *shortest* dictionary root, if one exists, and swap the word for that root. A trie built from the roots lets you walk each word one character at a time and stop at the very first end-of-word flag you hit, which is automatically the shortest matching root.

**Approach:** Insert all roots into a trie. For each word in the sentence, walk the trie; the moment you hit an end-of-word flag (or run out of characters or trie path), replace the word with the prefix walked so far, or keep the original word if no root matched.

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

```javascript +
class TrieNode {
    constructor() {
        this.children = new Map();
        this.isEndOfWord = false;
    }
}

function replaceWords(dictionary, sentence) {
    const rootTrie = new TrieNode();
    for (const root of dictionary) {
        let node = rootTrie;
        for (const ch of root) {
            if (!node.children.has(ch)) {
                node.children.set(ch, new TrieNode());
            }
            node = node.children.get(ch);
        }
        node.isEndOfWord = true;
    }

    function findRoot(word) {
        let node = rootTrie;
        let prefix = "";
        for (const ch of word) {
            if (!node.children.has(ch)) {
                return word; // no matching root, keep original
            }
            prefix += ch;
            node = node.children.get(ch);
            if (node.isEndOfWord) {
                return prefix;
            }
        }
        return word;
    }

    return sentence.split(" ").map(findRoot).join(" ");
}
```

```java +
import java.util.HashMap;
import java.util.Map;

public class Main {
    public static void main(String[] args) {
        String[] dictionary = {"cat", "bat", "rat"};
        String sentence = "the cattle was rattled by the battery";
        System.out.println(replaceWords(dictionary, sentence));
    }

    static TrieNode rootTrie;

    static String replaceWords(String[] dictionary, String sentence) {
        rootTrie = new TrieNode();
        for (String root : dictionary) {
            TrieNode node = rootTrie;
            for (char ch : root.toCharArray()) {
                node = node.children.computeIfAbsent(ch, c -> new TrieNode());
            }
            node.isEndOfWord = true;
        }

        StringBuilder result = new StringBuilder();
        for (String word : sentence.split(" ")) {
            if (result.length() > 0) result.append(" ");
            result.append(findRoot(word));
        }
        return result.toString();
    }

    static String findRoot(String word) {
        TrieNode node = rootTrie;
        StringBuilder prefix = new StringBuilder();
        for (char ch : word.toCharArray()) {
            if (!node.children.containsKey(ch)) {
                return word; // no matching root, keep original
            }
            prefix.append(ch);
            node = node.children.get(ch);
            if (node.isEndOfWord) {
                return prefix.toString();
            }
        }
        return word;
    }
}

class TrieNode {
    Map<Character, TrieNode> children = new HashMap<>();
    boolean isEndOfWord = false;
}
```

**Complexity:** Time O(total characters in the dictionary + total characters in the sentence), space O(total characters in the dictionary) for the trie.

**Common mistakes:** Not stopping at the *first* end-of-word flag reached. The problem wants the shortest matching root, so continuing past it would wrongly look for a longer one. Also, using a naive "try every root as a prefix" approach with string methods, which is O(words × roots × root length) instead of the trie's near-linear scan.

> **Remember:** stop at the first end-of-word flag you hit while walking down; that's always the shortest matching root.

```knowledge-check
{ "questions": [
    { "id": "dsa-tries-replace-words-q1", "type": "mcq",
      "prompt": "Why must find_root stop at the FIRST end-of-word flag it encounters while walking the trie?",
      "options": [
        {"id": "a", "text": "The problem asks for the shortest matching root, and continuing past the first match could find a longer, wrong one"},
        {"id": "b", "text": "Stopping early is only an optimization with no effect on correctness"},
        {"id": "c", "text": "Because tries can only store one word ending per path"},
        {"id": "d", "text": "Because longer roots are always invalid"}
      ],
      "correct": "a",
      "explanation": "If multiple roots are prefixes of each other (like 'cat' and 'catalog'), the shortest one that matches the word is the correct replacement. Stopping at the first end-of-word flag guarantees you get that shortest root." }
] }
```

## Maximum XOR of Two Numbers in an Array

[LeetCode 421](https://leetcode.com/problems/maximum-xor-of-two-numbers-in-an-array/) — Trie — Hard

To maximize the XOR of two numbers, you want their bits to differ at the highest positions possible, since a higher bit position contributes more to the result. A **binary trie**, where each node has at most 2 children (bit 0 or bit 1), lets you, for each number, greedily walk toward the *opposite* bit at every position. That greedy walk finds the best XOR partner for that number in O(32) steps instead of comparing it against every other number. It's the same prefix-tree idea from earlier in this lesson, applied to bits instead of letters.

**Approach:** Insert every number into a binary trie, most-significant-bit first (fixed 32-bit width). For each number, walk the trie trying to go the opposite direction of each of its bits; when the opposite branch doesn't exist, take the only branch available. Track the best XOR found.

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

```javascript +
class BinaryTrieNode {
    constructor() {
        this.children = new Map(); // 0 or 1 -> BinaryTrieNode
    }
}

function findMaximumXOR(nums) {
    const root = new BinaryTrieNode();
    const BITS = 31; // enough for LeetCode's constraint (nums < 2^31)

    function insert(num) {
        let node = root;
        for (let i = BITS; i >= 0; i--) {
            const bit = (num >> i) & 1;
            if (!node.children.has(bit)) {
                node.children.set(bit, new BinaryTrieNode());
            }
            node = node.children.get(bit);
        }
    }

    function query(num) {
        let node = root;
        let xor = 0;
        for (let i = BITS; i >= 0; i--) {
            const bit = (num >> i) & 1;
            const desired = 1 - bit; // the opposite bit maximizes this position's contribution
            if (node.children.has(desired)) {
                xor |= (1 << i);
                node = node.children.get(desired);
            } else {
                node = node.children.get(bit);
            }
        }
        return xor;
    }

    for (const num of nums) {
        insert(num);
    }

    return Math.max(...nums.map(query));
}
```

```java +
import java.util.HashMap;
import java.util.Map;

public class Main {
    public static void main(String[] args) {
        int[] nums = {3, 10, 5, 25, 2, 8};
        System.out.println(findMaximumXOR(nums));
    }

    static BinaryTrieNode root = new BinaryTrieNode();
    static final int BITS = 31; // enough for LeetCode's constraint (nums < 2^31)

    static int findMaximumXOR(int[] nums) {
        for (int num : nums) {
            insert(num);
        }

        int best = 0;
        for (int num : nums) {
            best = Math.max(best, query(num));
        }
        return best;
    }

    static void insert(int num) {
        BinaryTrieNode node = root;
        for (int i = BITS; i >= 0; i--) {
            int bit = (num >> i) & 1;
            node = node.children.computeIfAbsent(bit, b -> new BinaryTrieNode());
        }
    }

    static int query(int num) {
        BinaryTrieNode node = root;
        int xor = 0;
        for (int i = BITS; i >= 0; i--) {
            int bit = (num >> i) & 1;
            int desired = 1 - bit; // the opposite bit maximizes this position's contribution
            if (node.children.containsKey(desired)) {
                xor |= (1 << i);
                node = node.children.get(desired);
            } else {
                node = node.children.get(bit);
            }
        }
        return xor;
    }
}

class BinaryTrieNode {
    Map<Integer, BinaryTrieNode> children = new HashMap<>(); // 0 or 1 -> BinaryTrieNode
}
```

**Complexity:** Time O(n × 32) = O(n), space O(n × 32) for the trie nodes. Far better than the naive O(n²) pairwise XOR comparison.

**Common mistakes:** Iterating bits least-significant-first instead of most-significant-first. The greedy "prefer the opposite bit" strategy only produces the true maximum when higher bit positions are locked in before lower ones. Also, forgetting a fixed bit width, which lets negative numbers or inconsistent trie depths break the comparisons.

> **Remember:** a binary trie over bits, most significant first, walking toward the opposite bit at every step, turns "best XOR partner" into an O(32) walk.

```knowledge-check
{ "questions": [
    { "id": "dsa-tries-max-xor-q1", "type": "mcq",
      "prompt": "Why must the binary trie for Maximum XOR be built most-significant-bit first, not least-significant-bit first?",
      "options": [
        {"id": "a", "text": "The greedy 'take the opposite bit' strategy only maximizes the result if higher bit positions are decided before lower ones"},
        {"id": "b", "text": "Least-significant-first would make insertion run in O(n^2)"},
        {"id": "c", "text": "It only matters for negative numbers"},
        {"id": "d", "text": "Bit order makes no difference to correctness"}
      ],
      "correct": "a",
      "explanation": "A higher bit position contributes more to the XOR value than any combination of lower bits. Deciding bits from most significant to least, greedily, guarantees the largest possible value, which only works if higher bits are fixed first." }
] }
```
