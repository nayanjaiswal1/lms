---
kind: lesson
id_key: interview-prep-45/day-06
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Day 6 — Trees - Basics"
position: 6
estimated_minutes: 150
source:
    - 45-day-interview-roadmap.md
---
Trees are where recursion stops being optional and becomes the natural tool — most tree problems have a one-to-one mapping between the recursive structure of the tree and the recursive structure of the solution. Today builds the traversal vocabulary (inorder, preorder, postorder, level-order) that every later tree and graph problem assumes you already have automatic.

## Tree traversal: inorder, preorder, postorder, level-order

For a binary tree node with `left` and `right` children, the three depth-first traversals differ only in *when* you visit the node relative to its children:

- **Preorder**: node, left, right — visit the node before its subtrees. Useful for copying/serializing a tree top-down.
- **Inorder**: left, node, right — visit the node between its subtrees. For a BST, this produces sorted output (see Day 8).
- **Postorder**: left, right, node — visit the node after its subtrees. Useful when children must be fully processed first (deleting a tree, computing subtree aggregates).

**Level-order** (BFS) is different in kind — it visits nodes level by level, left to right, using a queue instead of recursion/stack.

```python
class TreeNode:
    def __init__(self, val=0, left=None, right=None):
        self.val = val
        self.left = left
        self.right = right

def preorder(root):
    if root is None:
        return []
    return [root.val] + preorder(root.left) + preorder(root.right)

def inorder(root):
    if root is None:
        return []
    return inorder(root.left) + [root.val] + inorder(root.right)

def postorder(root):
    if root is None:
        return []
    return postorder(root.left) + postorder(root.right) + [root.val]

from collections import deque

def level_order(root):
    if root is None:
        return []
    result = []
    queue = deque([root])
    while queue:
        level = []
        for _ in range(len(queue)):
            node = queue.popleft()
            level.append(node.val)
            if node.left:
                queue.append(node.left)
            if node.right:
                queue.append(node.right)
        result.append(level)
    return result
```

The list-concatenation versions above are readable but build intermediate lists; production code should pass an accumulator list by reference instead — know both forms.

## Recursive vs iterative traversal

Every DFS traversal has an iterative form using an explicit stack (see Day 5's stack-vs-recursion section). The tricky one is inorder, because you can't just push both children like preorder — you have to go all the way left first, then process, then go right:

```python
def inorder_iterative(root):
    result = []
    stack = []
    node = root
    while stack or node:
        while node:          # go as far left as possible
            stack.append(node)
            node = node.left
        node = stack.pop()   # process the node
        result.append(node.val)
        node = node.right    # then explore the right subtree
    return result
```

Interviewers ask for the iterative version to check whether you actually understand what the recursion is doing, not just that you memorized the three-line recursive function.

Preorder is the easiest to make iterative — push right before left so left pops first:

```python
def preorder_iterative(root):
    if root is None:
        return []
    result = []
    stack = [root]
    while stack:
        node = stack.pop()
        result.append(node.val)
        if node.right:
            stack.append(node.right)
        if node.left:
            stack.append(node.left)
    return result
```

Postorder iteratively is the fiddly one: compute preorder-but-"node, right, left" (swap the push order above) and reverse the result — that produces "left, right, node" for free.

```python
def postorder_iterative(root):
    if root is None:
        return []
    result = []
    stack = [root]
    while stack:
        node = stack.pop()
        result.append(node.val)
        if node.left:
            stack.append(node.left)
        if node.right:
            stack.append(node.right)
    return result[::-1]
```

## Tree properties

Two properties worth having cold since they recur constantly:

- **Height/depth**: height of a node is the number of edges on the longest path to a leaf below it; `height(None) = -1` (or 0, depending on convention — state which you're using). Computing height bottom-up is a natural postorder recursion.
- **Balanced**: a tree is height-balanced if, for every node, the heights of its left and right subtrees differ by at most 1. Checking balance naively (`height` at every node) is O(n²) in the worst case (skewed tree); the efficient version returns height and computes balance in a single postorder pass, O(n).

## Invert Binary Tree

[Invert Binary Tree (LeetCode 226)](https://leetcode.com/problems/invert-binary-tree/)

**Intuition:** Inverting means every node's left and right children swap, recursively, all the way down. This is a direct postorder-shaped recursion: invert both subtrees, then swap.

**Approach:** Base case: `None` inverts to `None`. Recursive case: swap `root.left` and `root.right`, having first recursively inverted each.

```python
def invert_tree(root):
    if root is None:
        return None
    root.left, root.right = invert_tree(root.right), invert_tree(root.left)
    return root
```

**Complexity:** Time O(n) — visits every node once. Space O(h) for the recursion stack, where h is tree height (O(log n) balanced, O(n) skewed).

**Common mistakes:**
- Swapping `root.left`/`root.right` *before* recursing on the original children — leads to inverting the wrong subtree or double-swapping. The simultaneous-assignment version above sidesteps this by evaluating both recursive calls before either assignment happens.
- Forgetting the `None` base case, causing infinite recursion or an `AttributeError`.

## Maximum Depth of Binary Tree

[Maximum Depth of Binary Tree (LeetCode 104)](https://leetcode.com/problems/maximum-depth-of-binary-tree/)

**Intuition:** The depth of a tree is 1 (for the current node) plus the deeper of its two subtrees' depths — a textbook postorder recursion.

**Approach:** Base case: an empty tree has depth 0. Recursive case: `1 + max(depth(left), depth(right))`.

```python
def max_depth(root) -> int:
    if root is None:
        return 0
    return 1 + max(max_depth(root.left), max_depth(root.right))
```

**Complexity:** Time O(n), space O(h) recursion stack.

**Common mistakes:**
- Off-by-one: forgetting the `+ 1` for the current node, or double-counting it.
- Attempting an iterative BFS solution without tracking level count correctly (must count levels, not just nodes).

## Same Tree

[Same Tree (LeetCode 100)](https://leetcode.com/problems/same-tree/)

**Intuition:** Two trees are identical if their roots have the same value and both subtree pairs are also identical — a direct structural recursion comparing two trees in lockstep.

**Approach:** Base cases: both `None` → equal; exactly one `None` → not equal. Recursive case: values match AND left subtrees match AND right subtrees match.

```python
def is_same_tree(p, q) -> bool:
    if p is None and q is None:
        return True
    if p is None or q is None:
        return False
    return (
        p.val == q.val
        and is_same_tree(p.left, q.left)
        and is_same_tree(p.right, q.right)
    )
```

**Complexity:** Time O(min(n, m)) — short-circuits as soon as trees diverge. Space O(min(h_p, h_q)) recursion stack.

**Common mistakes:**
- Checking `p.val == q.val` before checking either is `None`, causing an `AttributeError` on `None.val`.
- Using `and` short-circuiting correctly is fine here, but forgetting it and evaluating all three conditions unconditionally works too — just less efficient on divergent trees, not a correctness bug.

## Binary Tree Level Order Traversal

[Binary Tree Level Order Traversal (LeetCode 102)](https://leetcode.com/problems/binary-tree-level-order-traversal/)

**Intuition:** "Group nodes by depth level" is exactly what BFS naturally gives you if you process the queue one full level at a time instead of one node at a time.

**Approach:** Use a queue. At each iteration, snapshot the current queue length (`len(queue)`) — that's exactly how many nodes belong to the current level — pop that many, collecting their values and enqueuing their children.

```python
from collections import deque

def level_order_traversal(root):
    if root is None:
        return []
    result = []
    queue = deque([root])
    while queue:
        level_size = len(queue)
        level_values = []
        for _ in range(level_size):
            node = queue.popleft()
            level_values.append(node.val)
            if node.left:
                queue.append(node.left)
            if node.right:
                queue.append(node.right)
        result.append(level_values)
    return result
```

**Complexity:** Time O(n) — every node enqueued and dequeued once. Space O(w) for the queue, where w is the maximum tree width, plus O(n) for the output.

**Common mistakes:**
- Not snapshotting `len(queue)` before the inner loop — if you check `len(queue)` on each inner iteration, it changes as you enqueue children, merging levels together.
- Using a stack instead of a `deque` for the queue, or using `list.pop(0)` (O(n) per call) instead of `deque.popleft()` (O(1)).

## Key takeaways

- Preorder/inorder/postorder differ only in when the current node is visited relative to its children — a mnemonic: the traversal name tells you where "node" sits in "node, left, right."
- Level-order is BFS with a queue, not DFS with a stack — snapshot `len(queue)` at the top of each iteration to separate levels.
- Iterative inorder needs an explicit stack plus a "current node" pointer, because you must descend fully left before processing anything.
- Height-balance checks should compute height and balance in one bottom-up pass (O(n)), not recompute height at every node (O(n²)).
- Most binary-tree problems are a direct recursive translation of "do this for the node, combining results from left and right" — identify whether it's pre/in/postorder shaped before coding.

## Today's checklist

- [ ] Solve Invert Binary Tree
- [ ] Solve Maximum Depth of Binary Tree
- [ ] Solve Same Tree
- [ ] Solve Binary Tree Level Order Traversal
- [ ] Implement a tree node class
- [ ] Implement all four traversals iteratively and recursively
- [ ] Memorize: DFS uses stack or recursion, BFS uses queue
- [ ] Review: when to use preorder vs inorder vs postorder
