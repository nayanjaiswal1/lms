---
kind: lesson
id_key: interview-prep-45/day-08
course: interview-prep-45
section: dsa
section_title: "Data Structures & Algorithms"
section_position: 2
title: "Binary Search Trees and Rebuilding a Tree"
position: 9
estimated_minutes: 120
source:
    - 45-day-interview-roadmap.md
---
Think of a filing cabinet where every folder to the left of a given folder holds a smaller number, and every folder to the right holds a bigger one. That one rule, repeated at every level, is what turns a plain binary tree into a binary search tree (BST). It is a small rule with a big payoff: it makes search, insert, and delete run in O(log n) instead of O(n), and it opens up a whole family of "rebuild or validate this tree" interview problems.

## The BST rule

For every node in a BST: everything in its left subtree is smaller than the node's value, and everything in its right subtree is bigger. That rule holds transitively across the whole subtree, not just against the immediate children. A common bug, covered below, comes from checking it only one level down.

```python
class TreeNode:
    def __init__(self, val=0, left=None, right=None):
        self.val = val
        self.left = left
        self.right = right
```
```javascript +
class TreeNode {
    constructor(val = 0, left = null, right = null) {
        this.val = val;
        this.left = left;
        this.right = right;
    }
}
```
```java +
public class Main {
    public static void main(String[] args) {
        TreeNode root = new TreeNode(5, new TreeNode(3), new TreeNode(8));
        System.out.println("Root: " + root.val + ", left: " + root.left.val + ", right: " + root.right.val);
    }
}

class TreeNode {
    int val;
    TreeNode left;
    TreeNode right;

    TreeNode(int val) {
        this(val, null, null);
    }

    TreeNode(int val, TreeNode left, TreeNode right) {
        this.val = val;
        this.left = left;
        this.right = right;
    }
}
```

Take the tree built from inserting `5, 3, 8, 1, 4` in that order:

```
        5
       / \
      3   8
     / \
    1   4
```

Search, insert, and delete all cost O(h), where h is the tree's height. On a balanced tree that is O(log n), but on a degenerate tree, one built by inserting already-sorted data with no rebalancing, it collapses to a straight line and costs O(n). That's exactly why production databases and language runtimes use self-balancing trees (AVL, red-black) under the hood, even though building one yourself is outside interview scope.

> **Remember:** left is always smaller, right is always bigger, at every level, not just the first. That single rule is the whole BST.

```knowledge-check
{ "questions": [
    { "id": "dsa-bst-rule-q1", "type": "mcq",
      "prompt": "In a BST holding 5 at the root with left child 3 and right child 8, where can a value of 4 legally live?",
      "options": [
        {"id": "a", "text": "In 3's right subtree, since 4 is bigger than 3 but smaller than 5"},
        {"id": "b", "text": "Anywhere in the tree, position doesn't matter"},
        {"id": "c", "text": "Only as a direct child of the root"},
        {"id": "d", "text": "In 8's subtree, since 4 is a small number"}
      ],
      "correct": "a",
      "explanation": "4 is less than the root (5), so it belongs somewhere in the left subtree. Inside that subtree, 4 is greater than 3, so it lands as 3's right child." }
] }
```

## Why an inorder walk of a BST comes out sorted

Inorder visits left, then the node, then right. In a BST, left is always smaller and right is always bigger, so an inorder walk visits nodes in strictly increasing order. This one fact is the engine behind most BST-specific problems: find the kth smallest, check whether a tree is a valid BST, or turn a BST into a sorted list are all inorder traversal wearing a different name.

```python
def inorder_values(root):
    result = []
    def visit(node):
        if node is None:
            return
        visit(node.left)
        result.append(node.val)
        visit(node.right)
    visit(root)
    return result
```
```javascript +
function inorderValues(root) {
    const result = [];
    function visit(node) {
        if (node === null) {
            return;
        }
        visit(node.left);
        result.push(node.val);
        visit(node.right);
    }
    visit(root);
    return result;
}
```
```java +
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        TreeNode root = new TreeNode(2, new TreeNode(1), new TreeNode(3));
        System.out.println(inorderValues(root));
    }

    static List<Integer> inorderValues(TreeNode root) {
        List<Integer> result = new ArrayList<>();
        visit(root, result);
        return result;
    }

    static void visit(TreeNode node, List<Integer> result) {
        if (node == null) {
            return;
        }
        visit(node.left, result);
        result.add(node.val);
        visit(node.right, result);
    }
}

class TreeNode {
    int val;
    TreeNode left;
    TreeNode right;

    TreeNode(int val) {
        this(val, null, null);
    }

    TreeNode(int val, TreeNode left, TreeNode right) {
        this.val = val;
        this.left = left;
        this.right = right;
    }
}
```

Running this on the `5, 3, 8, 1, 4` tree from above gives `1, 3, 4, 5, 8`, in order, for free.

> **Remember:** inorder of a BST is always sorted. If a problem mentions "kth smallest" or "sorted", think inorder first.

```knowledge-check
{ "questions": [
    { "id": "dsa-bst-inorder-sorted-q1", "type": "mcq",
      "prompt": "Why does an inorder traversal of a BST always come out sorted?",
      "options": [
        {"id": "a", "text": "Because inorder visits left (smaller), then the node, then right (bigger), matching the BST's own ordering rule"},
        {"id": "b", "text": "Because BSTs sort their values automatically on insert"},
        {"id": "c", "text": "It only works if the tree is balanced"},
        {"id": "d", "text": "It's a coincidence specific to small trees"}
      ],
      "correct": "a",
      "explanation": "Inorder's visiting order (left, node, right) lines up exactly with the BST invariant (left smaller, right bigger) at every node, so the output is always ascending, on any BST shape." }
] }
```

## Inserting and searching

Both operations walk down from the root, comparing the target value at each node and choosing left or right, exactly the way you'd narrow down a phone book by comparing names.

```python
def bst_insert(root, val):
    if root is None:
        return TreeNode(val)
    if val < root.val:
        root.left = bst_insert(root.left, val)
    elif val > root.val:
        root.right = bst_insert(root.right, val)
    # val == root.val: no-op, assumes no duplicates
    return root

def bst_search(root, val) -> bool:
    if root is None:
        return False
    if val == root.val:
        return True
    return bst_search(root.left, val) if val < root.val else bst_search(root.right, val)
```
```javascript +
function bstInsert(root, val) {
    if (root === null) {
        return new TreeNode(val);
    }
    if (val < root.val) {
        root.left = bstInsert(root.left, val);
    } else if (val > root.val) {
        root.right = bstInsert(root.right, val);
    }
    // val === root.val: no-op, assumes no duplicates
    return root;
}

function bstSearch(root, val) {
    if (root === null) {
        return false;
    }
    if (val === root.val) {
        return true;
    }
    return val < root.val ? bstSearch(root.left, val) : bstSearch(root.right, val);
}
```
```java +
public class Main {
    public static void main(String[] args) {
        TreeNode root = null;
        int[] values = {5, 3, 8, 1, 4};
        for (int v : values) {
            root = bstInsert(root, v);
        }
        System.out.println("Search 4: " + bstSearch(root, 4));
        System.out.println("Search 9: " + bstSearch(root, 9));
    }

    static TreeNode bstInsert(TreeNode root, int val) {
        if (root == null) {
            return new TreeNode(val);
        }
        if (val < root.val) {
            root.left = bstInsert(root.left, val);
        } else if (val > root.val) {
            root.right = bstInsert(root.right, val);
        }
        // val == root.val: no-op, assumes no duplicates
        return root;
    }

    static boolean bstSearch(TreeNode root, int val) {
        if (root == null) {
            return false;
        }
        if (val == root.val) {
            return true;
        }
        return val < root.val ? bstSearch(root.left, val) : bstSearch(root.right, val);
    }
}

class TreeNode {
    int val;
    TreeNode left;
    TreeNode right;

    TreeNode(int val) {
        this(val, null, null);
    }

    TreeNode(int val, TreeNode left, TreeNode right) {
        this.val = val;
        this.left = left;
        this.right = right;
    }
}
```

Both run in O(h) time and O(h) space for the recursion stack. Written iteratively with a plain `while` loop instead of recursion, the space drops to O(1); mention that if asked to optimize space.

> **Remember:** insert and search both just follow the BST rule downward: smaller goes left, bigger goes right, until you fall off the tree or find the value.

```knowledge-check
{ "questions": [
    { "id": "dsa-bst-insert-search-q1", "type": "mcq",
      "prompt": "Why does writing bst_search iteratively instead of recursively save space?",
      "options": [
        {"id": "a", "text": "It avoids growing a call stack, dropping space from O(h) to O(1)"},
        {"id": "b", "text": "It makes the search faster in time complexity, from O(h) to O(1)"},
        {"id": "c", "text": "Recursive search doesn't work correctly on BSTs"},
        {"id": "d", "text": "It changes the result returned"}
      ],
      "correct": "a",
      "explanation": "Each recursive call adds a stack frame, costing O(h) space. A while loop reuses the same variables on each step instead, so no extra memory grows with the tree's height." }
] }
```

## Rebuilding a tree from two traversals

Given two of the three DFS traversals, you can rebuild the exact original tree, but only certain pairs work.

- **Preorder + inorder**: works. Preorder's first element is always the root. Inorder tells you which values sit in the left subtree (everything before the root's position) and which sit in the right subtree (everything after).
- **Postorder + inorder**: also works, the mirror image: postorder's *last* element is the root.
- **Preorder + postorder, with no inorder**: does not uniquely rebuild the tree if any node has only one child, since there's no way to tell whether that lone child is a left or right child. It only works if every node has either 0 or 2 children.
- **Preorder alone, or inorder alone**: never enough. Many different trees can share the same single traversal.

This is exactly the kind of "why does this work but not that" follow-up interviewers ask once you've solved the reconstruction problem below, so know the reasoning, not just the code.

> **Remember:** preorder or postorder tells you the root; inorder tells you how to split left from right. You need one of each.

```knowledge-check
{ "questions": [
    { "id": "dsa-bst-rebuild-pairs-q1", "type": "mcq",
      "prompt": "Which pair of traversals is NOT guaranteed to uniquely rebuild a binary tree?",
      "options": [
        {"id": "a", "text": "Preorder + postorder, when some node has exactly one child"},
        {"id": "b", "text": "Preorder + inorder"},
        {"id": "c", "text": "Postorder + inorder"},
        {"id": "d", "text": "All three pairs always work equally well"}
      ],
      "correct": "a",
      "explanation": "Without inorder, there's no way to know whether a node's single child is on the left or the right, so preorder + postorder alone can match more than one tree shape unless every node has 0 or 2 children." }
] }
```

## Validate Binary Search Tree

[Validate Binary Search Tree (LeetCode 98)](https://leetcode.com/problems/validate-binary-search-tree/)

The tempting but wrong check is comparing each node only to its immediate children. That misses violations further down, like a left-subtree node that's bigger than an ancestor two levels up. The fix: carry a `(low, high)` range down through the recursion, and tighten it as you go.

**Approach:** Recursively validate each node against a `(low, high)` bound. Going left tightens `high` to the current node's value; going right tightens `low`.

```python
def is_valid_bst(root) -> bool:
    def validate(node, low, high):
        if node is None:
            return True
        if not (low < node.val < high):
            return False
        return validate(node.left, low, node.val) and validate(node.right, node.val, high)

    return validate(root, float("-inf"), float("inf"))
```
```javascript +
function isValidBst(root) {
    function validate(node, low, high) {
        if (node === null) {
            return true;
        }
        if (!(low < node.val && node.val < high)) {
            return false;
        }
        return validate(node.left, low, node.val) && validate(node.right, node.val, high);
    }

    return validate(root, -Infinity, Infinity);
}
```
```java +
public class Main {
    public static void main(String[] args) {
        TreeNode root = new TreeNode(5, new TreeNode(3), new TreeNode(8));
        System.out.println(isValidBst(root));
    }

    static boolean isValidBst(TreeNode root) {
        return validate(root, Long.MIN_VALUE, Long.MAX_VALUE);
    }

    static boolean validate(TreeNode node, long low, long high) {
        if (node == null) {
            return true;
        }
        if (!(low < node.val && node.val < high)) {
            return false;
        }
        return validate(node.left, low, node.val) && validate(node.right, node.val, high);
    }
}

class TreeNode {
    int val;
    TreeNode left;
    TreeNode right;

    TreeNode(int val) {
        this(val, null, null);
    }

    TreeNode(int val, TreeNode left, TreeNode right) {
        this.val = val;
        this.left = left;
        this.right = right;
    }
}
```

**Complexity:** Time O(n), space O(h) recursion stack.

**Common mistakes:**
- Checking only immediate children instead of carrying a range down. That passes trees which are locally fine but globally broken.
- An alternative correct approach: run an inorder traversal and check the result is strictly increasing. Also O(n)/O(h), and arguably simpler to reason about, though it can't stop early when an invalid tree is found near the root.

> **Remember:** pass a shrinking (low, high) range down the recursion. A local left/right check alone is not enough.

```knowledge-check
{ "questions": [
    { "id": "dsa-bst-validate-q1", "type": "mcq",
      "prompt": "Why does checking only 'node.left.val < node.val < node.right.val' fail to validate a BST correctly?",
      "options": [
        {"id": "a", "text": "It misses violations further down the tree, such as a left-subtree node bigger than an ancestor two levels up"},
        {"id": "b", "text": "It's actually correct and sufficient"},
        {"id": "c", "text": "It only fails on trees with duplicate values"},
        {"id": "d", "text": "It runs in exponential time"}
      ],
      "correct": "a",
      "explanation": "A purely local check can't see the whole ancestor chain. A node deep in the left subtree could still be larger than some ancestor far above it, which only a range carried down through recursion catches." }
] }
```

## Lowest Common Ancestor of a BST

[Lowest Common Ancestor (LeetCode 235)](https://leetcode.com/problems/lowest-common-ancestor-of-a-binary-search-tree/)

In a plain binary tree, finding the lowest common ancestor (LCA) needs a full traversal. A BST's ordering gives a shortcut: if both target values are smaller than the current node, the LCA must be in the left subtree; if both are bigger, it's in the right subtree. The moment they land on opposite sides, or one equals the current node, that node is the split point, and the LCA.

**Approach:** Walk down from the root using the BST-ordering shortcut, stopping as soon as `p` and `q` diverge (or one matches the current node).

```python
def lowest_common_ancestor(root, p, q):
    node = root
    while node:
        if p.val < node.val and q.val < node.val:
            node = node.left
        elif p.val > node.val and q.val > node.val:
            node = node.right
        else:
            return node
    return None
```
```javascript +
function lowestCommonAncestor(root, p, q) {
    let node = root;
    while (node) {
        if (p.val < node.val && q.val < node.val) {
            node = node.left;
        } else if (p.val > node.val && q.val > node.val) {
            node = node.right;
        } else {
            return node;
        }
    }
    return null;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        TreeNode root = new TreeNode(6, new TreeNode(2, new TreeNode(0), new TreeNode(4)), new TreeNode(8));
        TreeNode p = root.left;
        TreeNode q = root.left.right;
        TreeNode lca = lowestCommonAncestor(root, p, q);
        System.out.println("LCA: " + lca.val);
    }

    static TreeNode lowestCommonAncestor(TreeNode root, TreeNode p, TreeNode q) {
        TreeNode node = root;
        while (node != null) {
            if (p.val < node.val && q.val < node.val) {
                node = node.left;
            } else if (p.val > node.val && q.val > node.val) {
                node = node.right;
            } else {
                return node;
            }
        }
        return null;
    }
}

class TreeNode {
    int val;
    TreeNode left;
    TreeNode right;

    TreeNode(int val) {
        this(val, null, null);
    }

    TreeNode(int val, TreeNode left, TreeNode right) {
        this.val = val;
        this.left = left;
        this.right = right;
    }
}
```

**Complexity:** Time O(h), space O(1), since it's iterative with no recursion stack.

**Common mistakes:**
- Using a general-tree LCA algorithm (search both subtrees, O(n)) when the BST property gives an O(h) shortcut. Interviewers read this as missing the BST constraint.
- Getting the divergence condition backwards, or forgetting that when one of `p`/`q` equals the current node, that node itself is the LCA.

> **Remember:** both smaller means go left, both bigger means go right, otherwise you've found the split point, and that's the LCA.

```knowledge-check
{ "questions": [
    { "id": "dsa-bst-lca-q1", "type": "mcq",
      "prompt": "In a BST, when should you stop walking down and declare the current node the lowest common ancestor of p and q?",
      "options": [
        {"id": "a", "text": "The moment p and q are no longer both smaller or both bigger than the current node"},
        {"id": "b", "text": "Only when you reach a leaf node"},
        {"id": "c", "text": "Only when p and q are equal to each other"},
        {"id": "d", "text": "Never; you must always search both subtrees fully"}
      ],
      "correct": "a",
      "explanation": "As long as both values are on the same side, the LCA must be further down that side. The split point, where they stop agreeing on a direction, is exactly the LCA." }
] }
```

## Construct Binary Tree from Preorder and Inorder Traversal

[Construct Binary Tree from Preorder and Inorder (LeetCode 105)](https://leetcode.com/problems/construct-binary-tree-from-preorder-and-inorder-traversal/)

Preorder's first element is always the root. Find that value's position in inorder: everything to its left belongs to the left subtree, everything to its right belongs to the right subtree. Recurse on each side using the matching slices of both traversals.

**Approach:** Build a hash map from value to inorder index for O(1) lookups, instead of scanning inorder each time, which would make the naive version O(n²). Track a moving pointer into preorder, since each recursive call consumes exactly one preorder element, the current subtree's root, before recursing further.

```python
def build_tree(preorder: list[int], inorder: list[int]):
    inorder_index = {val: i for i, val in enumerate(inorder)}
    self_preorder_idx = [0]  # mutable pointer into preorder

    def build(left, right):
        if left > right:
            return None
        root_val = preorder[self_preorder_idx[0]]
        self_preorder_idx[0] += 1
        root = TreeNode(root_val)
        mid = inorder_index[root_val]
        root.left = build(left, mid - 1)
        root.right = build(mid + 1, right)
        return root

    return build(0, len(inorder) - 1)
```
```javascript +
function buildTree(preorder, inorder) {
    const inorderIndex = new Map();
    inorder.forEach((val, i) => inorderIndex.set(val, i));
    let preorderIdx = 0; // mutable pointer into preorder

    function build(left, right) {
        if (left > right) {
            return null;
        }
        const rootVal = preorder[preorderIdx];
        preorderIdx += 1;
        const root = new TreeNode(rootVal);
        const mid = inorderIndex.get(rootVal);
        root.left = build(left, mid - 1);
        root.right = build(mid + 1, right);
        return root;
    }

    return build(0, inorder.length - 1);
}
```
```java +
import java.util.HashMap;
import java.util.Map;

public class Main {
    static int preorderIdx;

    public static void main(String[] args) {
        int[] preorder = {3, 9, 20, 15, 7};
        int[] inorder = {9, 3, 15, 20, 7};
        TreeNode root = buildTree(preorder, inorder);
        System.out.println("Root: " + root.val + ", left: " + root.left.val + ", right: " + root.right.val);
    }

    static TreeNode buildTree(int[] preorder, int[] inorder) {
        Map<Integer, Integer> inorderIndex = new HashMap<>();
        for (int i = 0; i < inorder.length; i++) {
            inorderIndex.put(inorder[i], i);
        }
        preorderIdx = 0; // mutable pointer into preorder
        return build(preorder, inorderIndex, 0, inorder.length - 1);
    }

    static TreeNode build(int[] preorder, Map<Integer, Integer> inorderIndex, int left, int right) {
        if (left > right) {
            return null;
        }
        int rootVal = preorder[preorderIdx];
        preorderIdx += 1;
        TreeNode root = new TreeNode(rootVal);
        int mid = inorderIndex.get(rootVal);
        root.left = build(preorder, inorderIndex, left, mid - 1);
        root.right = build(preorder, inorderIndex, mid + 1, right);
        return root;
    }
}

class TreeNode {
    int val;
    TreeNode left;
    TreeNode right;

    TreeNode(int val) {
        this(val, null, null);
    }

    TreeNode(int val, TreeNode left, TreeNode right) {
        this.val = val;
        this.left = left;
        this.right = right;
    }
}
```

**Complexity:** Time O(n), each node is processed once with an O(1) map lookup. Space O(n) for the map plus O(h) recursion stack.

**Common mistakes:**
- Using `inorder.index(root_val)`, a linear scan, instead of a precomputed hash map. That turns O(n) into O(n²).
- Slicing lists (`preorder[1:mid+1]`) instead of tracking indices. Correct, but it adds O(n) copying at every level, another hidden O(n²).
- Forgetting to advance the preorder pointer before recursing left. The left subtree's preorder elements come right after the root, so building the right side before consuming the left side's elements corrupts the indices.

> **Remember:** preorder's first element is the root; find it in inorder to split left from right; use a hash map, not a linear scan.

```knowledge-check
{ "questions": [
    { "id": "dsa-bst-build-tree-q1", "type": "mcq",
      "prompt": "Why precompute a value-to-index hash map for the inorder array before rebuilding the tree?",
      "options": [
        {"id": "a", "text": "It turns each root lookup into O(1) instead of an O(n) scan, avoiding a hidden O(n²) overall"},
        {"id": "b", "text": "It's required for the tree to be a valid BST"},
        {"id": "c", "text": "It reduces the space complexity to O(1)"},
        {"id": "d", "text": "It removes the need for a preorder pointer"}
      ],
      "correct": "a",
      "explanation": "Without the map, finding each root's split point in inorder means scanning it every time, O(n) per call across O(n) calls, which is O(n²) total. The map makes each lookup O(1)." }
] }
```

## Kth Smallest Element in a BST

[Kth Smallest Element in BST (LeetCode 230)](https://leetcode.com/problems/kth-smallest-element-in-a-bst/)

"Kth smallest" is exactly "the kth value visited during an inorder walk." No sorting needed; the BST's own structure hands you the order.

**Approach:** Do an inorder traversal, but stop the moment you've visited k elements. There's no need to build the full sorted list when k is small relative to n.

```python
def kth_smallest(root, k: int) -> int:
    stack = []
    node = root
    count = 0
    while stack or node:
        while node:
            stack.append(node)
            node = node.left
        node = stack.pop()
        count += 1
        if count == k:
            return node.val
        node = node.right
    raise ValueError("k is out of range")
```
```javascript +
function kthSmallest(root, k) {
    const stack = [];
    let node = root;
    let count = 0;
    while (stack.length > 0 || node !== null) {
        while (node !== null) {
            stack.push(node);
            node = node.left;
        }
        node = stack.pop();
        count += 1;
        if (count === k) {
            return node.val;
        }
        node = node.right;
    }
    throw new RangeError('k is out of range');
}
```
```java +
import java.util.ArrayDeque;
import java.util.Deque;

public class Main {
    public static void main(String[] args) {
        TreeNode root = new TreeNode(5, new TreeNode(3, new TreeNode(2), new TreeNode(4)), new TreeNode(8));
        System.out.println(kthSmallest(root, 3));
    }

    static int kthSmallest(TreeNode root, int k) {
        Deque<TreeNode> stack = new ArrayDeque<>();
        TreeNode node = root;
        int count = 0;
        while (!stack.isEmpty() || node != null) {
            while (node != null) {
                stack.push(node);
                node = node.left;
            }
            node = stack.pop();
            count += 1;
            if (count == k) {
                return node.val;
            }
            node = node.right;
        }
        throw new IllegalArgumentException("k is out of range");
    }
}

class TreeNode {
    int val;
    TreeNode left;
    TreeNode right;

    TreeNode(int val) {
        this(val, null, null);
    }

    TreeNode(int val, TreeNode left, TreeNode right) {
        this.val = val;
        this.left = left;
        this.right = right;
    }
}
```

**Complexity:** Time O(h + k): descending to the leftmost node costs O(h), then visiting k more nodes, worst case O(n) if k is close to n. Space O(h) for the stack.

**Common mistakes:**
- Building the entire inorder list first, then indexing into it. Correct, but it wastes time and space when k is small, since there's no early exit.
- Off-by-one: k is usually 1-indexed, so return when `count == k`, not `count == k - 1`.

> **Remember:** an iterative inorder walk that stops at count k, no need to build the full sorted list first.

```knowledge-check
{ "questions": [
    { "id": "dsa-bst-kth-smallest-q1", "type": "mcq",
      "prompt": "Why is stopping the inorder traversal early, as soon as count equals k, better than building the full sorted list first?",
      "options": [
        {"id": "a", "text": "It avoids wasted time and space visiting nodes beyond the kth one when k is small relative to n"},
        {"id": "b", "text": "It changes the time complexity from O(n) to O(1)"},
        {"id": "c", "text": "The full list approach gives a wrong answer"},
        {"id": "d", "text": "It only matters for unbalanced trees"}
      ],
      "correct": "a",
      "explanation": "Stopping at k avoids visiting the remaining n - k nodes. When k is much smaller than n, this saves real time and space; when k is close to n, the cost is about the same either way." }
] }
```
