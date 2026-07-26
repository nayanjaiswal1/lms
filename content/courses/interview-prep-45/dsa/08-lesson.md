---
kind: lesson
id_key: interview-prep-45/day-08
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Trees - BST and Reconstruction"
position: 8
estimated_minutes: 120
source:
    - 45-day-interview-roadmap.md
---
A binary search tree adds one ordering invariant to a plain binary tree, and that single invariant is what makes search, insert, and delete O(log n) instead of O(n) — and what makes an entire class of "validate/rebuild this tree" problems tractable. Today covers BST properties and the traversal-based reconstruction problems that regularly appear in on-site rounds.

## BST properties

A binary search tree maintains: for every node, all values in its left subtree are less than the node's value, and all values in its right subtree are greater. This must hold *transitively* for the whole subtree, not just the immediate children — a common bug source, covered below.

```python
class TreeNode:
    def __init__(self, val=0, left=None, right=None):
        self.val = val
        self.left = left
        self.right = right
```

**Interview-relevant complexity:** search/insert/delete are O(h) where h is tree height — O(log n) if the tree is balanced, but O(n) in the worst case for a degenerate (linked-list-shaped) BST, e.g., inserting already-sorted data without rebalancing. This is exactly why self-balancing trees (AVL, red-black) exist in production databases and language runtimes, even though they're out of scope for a basic BST implementation.

## Inorder traversal of BST is sorted

Because inorder visits left, node, right — and left is always smaller, right is always larger — an inorder traversal of a BST visits nodes in strictly ascending order. This single fact underlies most BST-specific problems: "find the kth smallest," "validate the BST," and "convert BST to sorted list" are all inorder traversal in disguise.

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

## BST insert and search

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

Both are O(h) time, O(h) space for the recursion stack (or O(1) if written iteratively with a `while` loop instead of recursion — worth showing the iterative version if asked to optimize space).

## Tree reconstruction from traversals

Given two of the three DFS traversals, you can rebuild the exact original tree — but only certain pairs work:

- **Preorder + inorder**: works. Preorder's first element is always the root; inorder tells you which elements are in the left subtree (everything before the root's position) versus the right subtree (everything after).
- **Postorder + inorder**: works, symmetric to the above — postorder's *last* element is the root.
- **Preorder + postorder alone (no inorder)**: does NOT uniquely reconstruct the tree if any node has only one child — there's ambiguity about whether that child is a left or right child. Only works if you're told the tree is "full" (every node has 0 or 2 children).
- **Preorder alone, or inorder alone**: never sufficient — many different trees share the same single traversal.

This is exactly the kind of "why does this work but not that" question interviewers ask as a follow-up after you solve the reconstruction problem — know the answer, don't just implement the algorithm.

## Validate Binary Search Tree

[Validate Binary Search Tree (LeetCode 98)](https://leetcode.com/problems/validate-binary-search-tree/)

**Intuition:** The naive bug is checking only `node.left.val < node.val < node.right.val` — that's a *local* check and misses violations further down the tree (e.g., a left-subtree node that's larger than an ancestor two levels up). The fix is passing down a valid `(low, high)` range that narrows as you descend.

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

**Complexity:** Time O(n), space O(h) recursion stack.

**Common mistakes:**
- Checking only immediate children instead of propagating a range — passes for trees that are locally-but-not-globally valid.
- An alternative correct approach: do an inorder traversal and check the output is strictly increasing — also O(n)/O(h), and arguably simpler to reason about, but doesn't short-circuit as early on an invalid tree found near the root.

## Lowest Common Ancestor of a BST

[Lowest Common Ancestor (LeetCode 235)](https://leetcode.com/problems/lowest-common-ancestor-of-a-binary-search-tree/)

**Intuition:** In a general binary tree, finding the LCA needs full traversal. In a BST, ordering gives you a shortcut: if both target values are less than the current node, the LCA must be in the left subtree; if both are greater, it's in the right subtree; the moment they're on opposite sides (or one equals the current node), you've found the split point — that's the LCA.

**Approach:** Walk down from the root, following the BST-ordering shortcut, stopping as soon as `p` and `q` diverge (or one matches the current node).

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

**Complexity:** Time O(h), space O(1) (iterative — no recursion stack needed).

**Common mistakes:**
- Using a general-tree LCA algorithm (search both subtrees, O(n)) when the BST property gives an O(h) shortcut — a red flag to interviewers that you didn't notice the BST constraint.
- Getting the divergence condition backwards, or forgetting the case where one of `p`/`q` equals the current node (that node is itself the LCA).

## Construct Binary Tree from Preorder and Inorder Traversal

[Construct Binary Tree from Preorder and Inorder (LeetCode 105)](https://leetcode.com/problems/construct-binary-tree-from-preorder-and-inorder-traversal/)

**Intuition:** Preorder's first element is the root. Find that value's position in inorder — everything to its left in inorder belongs to the left subtree, everything to its right belongs to the right subtree. Recurse on each side using the corresponding slices of both traversals.

**Approach:** Use a hash map from value to inorder index for O(1) lookups (instead of scanning inorder each time, which would make the naive version O(n²)). Track a moving pointer into preorder since each recursive call consumes exactly one preorder element (the current subtree's root) before recursing further.

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

**Complexity:** Time O(n) — each node processed once, O(1) map lookup per node. Space O(n) for the map plus O(h) recursion stack.

**Common mistakes:**
- Using `inorder.index(root_val)` (a linear scan) instead of a precomputed hash map — turns O(n) into O(n²).
- Slicing lists (`preorder[1:mid+1]`) instead of tracking indices — correct but adds O(n) copying at every level, another hidden O(n²).
- Forgetting to advance the preorder pointer *before* recursing left (left subtree's preorder elements come immediately after the root in preorder order — if you build right before consuming left's elements, indices get corrupted).

## Kth Smallest Element in a BST

[Kth Smallest Element in BST (LeetCode 230)](https://leetcode.com/problems/kth-smallest-element-in-a-bst/)

**Intuition:** "Kth smallest" is exactly "the kth element visited during inorder traversal" — no sorting needed, the BST's structure does it for you.

**Approach:** Do an inorder traversal, but stop early the moment you've visited k elements — no need to build the full sorted list if k is small relative to n.

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

**Complexity:** Time O(h + k) — descends to the leftmost node (O(h)) then visits k more nodes; worst case O(n) if k is close to n. Space O(h) for the stack.

**Common mistakes:**
- Building the entire inorder list first, then indexing `result[k-1]` — correct but wastes time/space when k is small (no early exit).
- Off-by-one: k is typically 1-indexed in these problems, so return on `count == k`, not `count == k - 1`.

## Key takeaways

- BST ordering makes search/insert/delete O(h), not O(log n) unconditionally — a degenerate (sorted-insert) BST is O(n) per operation.
- Inorder traversal of a BST is sorted — this fact is the key to Validate BST, Kth Smallest, and BST-to-sorted-list problems.
- BST LCA is O(h) using the ordering shortcut; don't fall back to the general-tree O(n) algorithm when the BST property is available.
- Tree reconstruction needs preorder+inorder or postorder+inorder — preorder+postorder alone is ambiguous unless every node has 0 or 2 children.
- Validate BST must pass down a tightening `(low, high)` range — checking only immediate parent-child relationships is a classic, easy-to-miss bug.
