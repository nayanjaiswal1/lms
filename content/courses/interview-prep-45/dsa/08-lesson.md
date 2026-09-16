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
A binary search tree adds one ordering invariant to a plain binary tree. That single invariant is what makes search, insert, and delete O(log n) instead of O(n), and it's what makes an entire class of validate-or-rebuild-this-tree problems tractable. Today covers BST properties and the traversal-based reconstruction problems that regularly appear in on-site rounds.

## BST properties

A binary search tree maintains one rule: for every node, all values in its left subtree are less than the node's value, and all values in its right subtree are greater. That rule applies transitively across the entire subtree. A common bug, covered below, comes from checking it only against immediate children.

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

**Interview-relevant complexity:** search, insert, and delete are O(h), where h is tree height. That's O(log n) when the tree is balanced, but O(n) in the worst case for a degenerate, linked-list-shaped BST, such as one built by inserting already-sorted data without rebalancing. It's exactly why self-balancing trees (AVL, red-black) exist in production databases and language runtimes, even though building one is out of scope here.

## Inorder traversal of BST is sorted

Inorder visits left, node, right, and since left is always smaller and right is always larger, an inorder traversal of a BST visits nodes in strictly ascending order. This single fact underlies most BST-specific problems: find the kth smallest, validate the BST, and convert BST to sorted list are all inorder traversal in disguise.

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

Both run in O(h) time and O(h) space for the recursion stack. Written iteratively with a `while` loop instead, space drops to O(1); worth showing that version if asked to optimize space.

## Tree reconstruction from traversals

Given two of the three DFS traversals, you can rebuild the exact original tree, though only certain pairs actually work:

- **Preorder + inorder**: works. Preorder's first element is always the root; inorder tells you which elements are in the left subtree (everything before the root's position) versus the right subtree (everything after).
- **Postorder + inorder**: works too, symmetric to the pair above: postorder's last element is the root.
- **Preorder + postorder alone (no inorder)**: does not uniquely reconstruct the tree if any node has only one child, since there's ambiguity about whether that child is a left or right child. It only works if the tree is known to be "full" (every node has 0 or 2 children).
- **Preorder alone, or inorder alone**: never sufficient, since many different trees share the same single traversal.

This is exactly the kind of "why does this work but not that" question interviewers ask as a follow-up once you've solved the reconstruction problem, so know the reasoning, not just the implementation.

## Validate Binary Search Tree

[Validate Binary Search Tree (LeetCode 98)](https://leetcode.com/problems/validate-binary-search-tree/)

**Intuition:** The naive bug is checking only `node.left.val < node.val < node.right.val`. That's a local check, and it misses violations further down the tree, such as a left-subtree node that's larger than an ancestor two levels up. The fix is passing down a valid `(low, high)` range that narrows as you descend.

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
- Checking only immediate children instead of propagating a range: passes for trees that are locally valid but globally broken.
- An alternative correct approach: run an inorder traversal and check the output is strictly increasing. Also O(n)/O(h), and arguably simpler to reason about, though it won't short-circuit as early when an invalid tree is found near the root.

## Lowest Common Ancestor of a BST

[Lowest Common Ancestor (LeetCode 235)](https://leetcode.com/problems/lowest-common-ancestor-of-a-binary-search-tree/)

**Intuition:** In a general binary tree, finding the LCA needs a full traversal. In a BST, ordering gives you a shortcut: if both target values are less than the current node, the LCA must be in the left subtree; if both are greater, it's in the right subtree. The moment they land on opposite sides, or one equals the current node, you've found the split point: that's the LCA.

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

**Complexity:** Time O(h), space O(1) since it's iterative and needs no recursion stack.

**Common mistakes:**
- Using a general-tree LCA algorithm (search both subtrees, O(n)) when the BST property gives an O(h) shortcut. Interviewers read this as a sign you missed the BST constraint.
- Getting the divergence condition backwards, or forgetting the case where one of `p`/`q` equals the current node, in which case that node is itself the LCA.

## Construct Binary Tree from Preorder and Inorder Traversal

[Construct Binary Tree from Preorder and Inorder (LeetCode 105)](https://leetcode.com/problems/construct-binary-tree-from-preorder-and-inorder-traversal/)

**Intuition:** Preorder's first element is the root. Find that value's position in inorder: everything to its left belongs to the left subtree, everything to its right belongs to the right subtree. Recurse on each side using the corresponding slices of both traversals.

**Approach:** Use a hash map from value to inorder index for O(1) lookups instead of scanning inorder each time, which would make the naive version O(n²). Track a moving pointer into preorder, since each recursive call consumes exactly one preorder element (the current subtree's root) before recursing further.

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

**Complexity:** Time O(n), since each node is processed once with an O(1) map lookup. Space O(n) for the map plus O(h) recursion stack.

**Common mistakes:**
- Using `inorder.index(root_val)`, a linear scan, instead of a precomputed hash map. Turns O(n) into O(n²).
- Slicing lists (`preorder[1:mid+1]`) instead of tracking indices. Correct, but it adds O(n) copying at every level, another hidden O(n²).
- Forgetting to advance the preorder pointer before recursing left. Left subtree's preorder elements come immediately after the root, so building right before consuming left's elements corrupts the indices.

## Kth Smallest Element in a BST

[Kth Smallest Element in BST (LeetCode 230)](https://leetcode.com/problems/kth-smallest-element-in-a-bst/)

**Intuition:** "Kth smallest" is exactly "the kth element visited during inorder traversal." No sorting needed; the BST's structure does it for you.

**Approach:** Do an inorder traversal, but stop early the moment you've visited k elements. There's no need to build the full sorted list if k is small relative to n.

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

**Complexity:** Time O(h + k): it descends to the leftmost node in O(h), then visits k more nodes, worst case O(n) if k is close to n. Space O(h) for the stack.

**Common mistakes:**
- Building the entire inorder list first, then indexing `result[k-1]`. Correct, but wastes time and space when k is small since there's no early exit.
- Off-by-one: k is typically 1-indexed in these problems, so return on `count == k`, not `count == k - 1`.
